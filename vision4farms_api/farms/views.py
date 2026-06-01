import secrets
import string
from datetime import timedelta
from django.utils import timezone
from django.utils.text import slugify
from django.core.mail import send_mail
from django.conf import settings
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Farms, ProfilesHasFarms, ProfilesHasCompanies, Companies, FarmInvites
from .serializers import FarmSerializer, FarmCreateSerializer, CompanySerializer, CompanyCreateSerializer

# Roles
ROLE_GESTOR = 1
ROLE_COLABORADOR = 2
ROLE_CONSULTOR = 3

ROLE_LABELS = {
    ROLE_GESTOR: 'Gestor',
    ROLE_COLABORADOR: 'Colaborador',
    ROLE_CONSULTOR: 'Consultor',
}


def _generate_invite_code():
    chars = string.ascii_uppercase + string.digits
    while True:
        code = ''.join(secrets.choice(chars) for _ in range(8))
        if not FarmInvites.objects.filter(invite_code=code).exists():
            return code


def _get_profile_id(user):
    return user.profile.profile_id


def _get_user_role(user, farm_id):
    """Devolve o role do utilizador numa farm, ou None se não tiver acesso."""
    try:
        phf = ProfilesHasFarms.objects.get(
            profile_id=_get_profile_id(user),
            farm_id=farm_id,
            connection_status=1,
            deleted_at__isnull=True,
        )
        return phf.connection_role
    except ProfilesHasFarms.DoesNotExist:
        return None


def _is_gestor(user, farm_id):
    return _get_user_role(user, farm_id) == ROLE_GESTOR


# ── Farms ──────────────────────────────────────────────────

class FarmListView(generics.ListAPIView):
    serializer_class = FarmSerializer

    def get_queryset(self):
        user = self.request.user
        try:
            profile_id = _get_profile_id(user)
            farm_ids = ProfilesHasFarms.objects.filter(
                profile_id=profile_id,
                connection_status=1,
                deleted_at__isnull=True
            ).values_list('farm_id', flat=True)
            return Farms.objects.filter(
                farm_id__in=farm_ids,
                farm_status=1,
                deleted_at__isnull=True
            )
        except Exception:
            return Farms.objects.none()


class FarmDetailView(generics.RetrieveAPIView):
    queryset = Farms.objects.filter(farm_status=1, deleted_at__isnull=True)
    serializer_class = FarmSerializer
    lookup_field = 'farm_id'


class FarmCreateView(APIView):

    def post(self, request):
        user = request.user
        try:
            profile_id = _get_profile_id(user)
            phc = ProfilesHasCompanies.objects.filter(
                profile_id=profile_id,
                connection_status=1,
                deleted_at__isnull=True
            ).first()
            if not phc:
                return Response(
                    {'detail': 'Utilizador não tem empresa associada.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            company_id = phc.company_id
        except Exception as e:
            return Response({'detail': f'Erro: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)

        farm_name = request.data.get('farm_name', '').strip()
        data = {
            'farm_name': farm_name,
            'farm_slug': slugify(farm_name),
            'farm_address': request.data.get('farm_address', ''),
            'farm_city': request.data.get('farm_city', ''),
            'farm_district': request.data.get('farm_district', ''),
            'farm_country': request.data.get('farm_country', 'Portugal'),
            'farm_description': request.data.get('farm_description', ''),
            'farm_status': 1,
            'current_company': company_id,
        }

        serializer = FarmCreateSerializer(data=data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        farm = serializer.save(created_by=user.user_id)

        try:
            ProfilesHasFarms.objects.create(
                farm_id=farm.farm_id,
                profile_id=profile_id,
                connection_date=timezone.now().date(),
                connection_role=ROLE_GESTOR,
                connection_status=1,
                default_farm=1,
                created_by=user.user_id,
            )
        except Exception:
            pass

        return Response(FarmSerializer(farm).data, status=status.HTTP_201_CREATED)


# ── Company ────────────────────────────────────────────────

class CompanyCreateView(APIView):

    def post(self, request):
        user = request.user
        try:
            profile_id = _get_profile_id(user)
            existing = ProfilesHasCompanies.objects.filter(
                profile_id=profile_id,
                connection_status=1,
                deleted_at__isnull=True
            ).first()
            if existing:
                return Response(
                    {'detail': 'Utilizador já tem uma empresa associada.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except Exception as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        serializer = CompanyCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        company = serializer.save(created_by=user.user_id)

        try:
            ProfilesHasCompanies.objects.create(
                profile_id=profile_id,
                company_id=company.company_id,
                connection_status=1,
                connection_role=1,
                default_company=1,
                created_by=user.user_id,
                connection_start_date=timezone.now().date(),
            )
        except Exception as e:
            return Response(
                {'detail': f'Empresa criada mas erro ao associar: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        return Response(CompanySerializer(company).data, status=status.HTTP_201_CREATED)


# ── Convites ───────────────────────────────────────────────

class InviteGenerateView(APIView):
    """Gestor gera código de convite para uma exploração, com role e email opcional."""

    def post(self, request, farm_id):
        user = request.user

        if not _is_gestor(user, farm_id):
            return Response(
                {'detail': 'Sem permissão. Apenas gestores podem gerar convites.'},
                status=status.HTTP_403_FORBIDDEN
            )

        try:
            farm = Farms.objects.get(farm_id=farm_id)
        except Farms.DoesNotExist:
            return Response({'detail': 'Exploração não encontrada.'}, status=status.HTTP_404_NOT_FOUND)

        invite_role = int(request.data.get('invite_role', ROLE_COLABORADOR))
        invite_email = request.data.get('invite_email', '').strip() or None

        if invite_role not in [ROLE_GESTOR, ROLE_COLABORADOR, ROLE_CONSULTOR]:
            return Response({'detail': 'Role inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        # Cancelar convites ativos anteriores para o mesmo email (se fornecido)
        if invite_email:
            FarmInvites.objects.filter(
                farm_id=farm_id,
                invite_email=invite_email,
                invite_status=0,
            ).update(invite_status=3)

        code = _generate_invite_code()
        invite = FarmInvites.objects.create(
            farm_id=farm_id,
            invite_code=code,
            invite_email=invite_email,
            invite_role=invite_role,
            invite_status=0,
            expires_at=timezone.now() + timedelta(days=7),
            created_by=user.user_id,
        )

        # Enviar email se fornecido
        if invite_email:
            try:
                register_link = f"vision4farms://invite?code={code}"
                send_mail(
                    subject=f'Convite para {farm.farm_name} — Vision4Farms',
                    message=(
                        f'Olá!\n\n'
                        f'Foste convidado para te juntar à exploração "{farm.farm_name}" '
                        f'como {ROLE_LABELS.get(invite_role, "Colaborador")} na plataforma Vision4Farms.\n\n'
                        f'O teu código de convite é:\n\n'
                        f'    {code}\n\n'
                        f'Este convite é válido durante 7 dias.\n\n'
                        f'Se ainda não tens conta, regista-te em Vision4Farms e introduz este código.\n\n'
                        f'Equipa Vision4Farms'
                    ),
                    from_email=None,
                    recipient_list=[invite_email],
                    fail_silently=False,
                )
                email_sent = True
            except Exception:
                email_sent = False
        else:
            email_sent = False

        return Response({
            'invite_code': invite.invite_code,
            'invite_role': invite_role,
            'invite_role_label': ROLE_LABELS.get(invite_role),
            'farm_name': farm.farm_name,
            'expires_at': invite.expires_at,
            'email_sent': email_sent,
        }, status=status.HTTP_201_CREATED)


class InviteJoinView(APIView):
    """Utilizador entra na exploração com código de convite."""

    def post(self, request):
        user = request.user
        code = request.data.get('invite_code', '').strip().upper()

        if not code:
            return Response({'detail': 'Código obrigatório.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            invite = FarmInvites.objects.get(invite_code=code, invite_status=0)
        except FarmInvites.DoesNotExist:
            return Response({'detail': 'Código inválido ou já utilizado.'}, status=status.HTTP_400_BAD_REQUEST)

        if timezone.now() > invite.expires_at:
            invite.invite_status = 2
            invite.save(update_fields=['invite_status'])
            return Response({'detail': 'Código expirado. Pede um novo ao gestor.'}, status=status.HTTP_400_BAD_REQUEST)

        profile_id = _get_profile_id(user)

        existing = ProfilesHasFarms.objects.filter(
            profile_id=profile_id,
            farm_id=invite.farm_id,
            deleted_at__isnull=True,
        ).first()

        if existing:
            if existing.connection_status == 1:
                return Response({'detail': 'Já tens acesso a esta exploração.'}, status=status.HTTP_400_BAD_REQUEST)
            else:
                existing.connection_status = 1
                existing.connection_role = invite.invite_role
                existing.save(update_fields=['connection_status', 'connection_role'])
        else:
            ProfilesHasFarms.objects.create(
                farm_id=invite.farm_id,
                profile_id=profile_id,
                connection_date=timezone.now().date(),
                connection_role=invite.invite_role,
                connection_status=1,
                default_farm=0,
                created_by=user.user_id,
            )

        invite.invite_status = 1
        invite.used_at = timezone.now()
        invite.used_by = user.user_id
        invite.save(update_fields=['invite_status', 'used_at', 'used_by'])

        farm = Farms.objects.get(farm_id=invite.farm_id)
        return Response({
            'detail': f'Entraste na exploração "{farm.farm_name}" como {ROLE_LABELS.get(invite.invite_role)}!',
            'farm_id': farm.farm_id,
            'farm_name': farm.farm_name,
            'role': invite.invite_role,
            'role_label': ROLE_LABELS.get(invite.invite_role),
        })


class InviteListView(APIView):
    """Gestor vê lista de convites enviados para as suas explorações."""

    def get(self, request):
        user = request.user
        profile_id = _get_profile_id(user)

        managed_farm_ids = ProfilesHasFarms.objects.filter(
            profile_id=profile_id,
            connection_role=ROLE_GESTOR,
            connection_status=1,
            deleted_at__isnull=True,
        ).values_list('farm_id', flat=True)

        farm_id_filter = request.query_params.get('farm_id')
        invites_qs = FarmInvites.objects.filter(farm_id__in=managed_farm_ids)
        if farm_id_filter:
            invites_qs = invites_qs.filter(farm_id=farm_id_filter)

        invites_qs = invites_qs.order_by('-created_at')

        # Atualizar expirados
        now = timezone.now()
        invites_qs.filter(invite_status=0, expires_at__lt=now).update(invite_status=2)

        result = []
        for inv in invites_qs:
            result.append({
                'invite_id': inv.invite_id,
                'invite_code': inv.invite_code,
                'invite_email': inv.invite_email,
                'invite_role': inv.invite_role,
                'invite_role_label': ROLE_LABELS.get(inv.invite_role, ''),
                'invite_status': inv.invite_status,
                'invite_status_label': {0: 'Ativo', 1: 'Aceite', 2: 'Expirado', 3: 'Cancelado'}.get(inv.invite_status, ''),
                'farm_id': inv.farm_id,
                'farm_name': inv.farm.farm_name,
                'expires_at': inv.expires_at,
                'used_at': inv.used_at,
                'created_at': inv.created_at,
            })

        return Response(result)


class InviteCancelView(APIView):
    """Gestor cancela um convite ativo."""

    def post(self, request, invite_id):
        user = request.user
        try:
            invite = FarmInvites.objects.get(invite_id=invite_id)
        except FarmInvites.DoesNotExist:
            return Response({'detail': 'Convite não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        if not _is_gestor(user, invite.farm_id):
            return Response({'detail': 'Sem permissão.'}, status=status.HTTP_403_FORBIDDEN)

        if invite.invite_status != 0:
            return Response({'detail': 'Este convite não pode ser cancelado.'}, status=status.HTTP_400_BAD_REQUEST)

        invite.invite_status = 3
        invite.save(update_fields=['invite_status'])
        return Response({'detail': 'Convite cancelado.'})


# ── Pedidos de acesso ──────────────────────────────────────

class AccessPendingView(APIView):
    """Gestor vê pedidos de acesso pendentes."""

    def get(self, request):
        user = request.user
        profile_id = _get_profile_id(user)

        managed_farm_ids = ProfilesHasFarms.objects.filter(
            profile_id=profile_id,
            connection_role=ROLE_GESTOR,
            connection_status=1,
            deleted_at__isnull=True,
        ).values_list('farm_id', flat=True)

        pending = ProfilesHasFarms.objects.filter(
            farm_id__in=managed_farm_ids,
            connection_status=0,
            deleted_at__isnull=True,
        ).select_related('farm')

        result = []
        for p in pending:
            try:
                from authentication.models import Profiles
                profile = Profiles.objects.get(profile_id=p.profile_id)
                profile_name = profile.profile_name
                profile_email = profile.profile_email
            except Exception:
                profile_name = f'Utilizador #{p.profile_id}'
                profile_email = ''

            result.append({
                'row_id': p.row_id,
                'farm_id': p.farm_id,
                'farm_name': p.farm.farm_name,
                'profile_id': p.profile_id,
                'profile_name': profile_name,
                'profile_email': profile_email,
                'connection_date': p.connection_date,
            })

        return Response(result)


class AccessApproveView(APIView):
    """Gestor aprova ou recusa pedido de acesso."""

    def post(self, request, row_id):
        user = request.user
        action = request.data.get('action', '')

        try:
            phf = ProfilesHasFarms.objects.get(row_id=row_id, connection_status=0)
        except ProfilesHasFarms.DoesNotExist:
            return Response({'detail': 'Pedido não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        if not _is_gestor(user, phf.farm_id):
            return Response({'detail': 'Sem permissão.'}, status=status.HTTP_403_FORBIDDEN)

        if action == 'approve':
            phf.connection_status = 1
            phf.save(update_fields=['connection_status'])
            return Response({'detail': 'Acesso aprovado.'})
        elif action == 'reject':
            phf.connection_status = 2
            phf.save(update_fields=['connection_status'])
            return Response({'detail': 'Acesso recusado.'})
        else:
            return Response({'detail': 'Ação inválida.'}, status=status.HTTP_400_BAD_REQUEST)