"""
Views de autenticação — registo só por convite, password reset por link URL.
"""
import os
import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.utils import timezone
from django.shortcuts import render
from django.http import HttpResponse
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Users, Profiles, LoginHistory
from .serializers import (
    LoginSerializer, MeSerializer, RegisterSerializer,
    ProfileSerializer, ProfileUpdateSerializer,
)


def _get_tokens(user):
    refresh = RefreshToken()
    refresh['user_id'] = user.user_id
    refresh['username'] = user.username
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


# ── Página HTML de reset (acedida pelo link do email) ──────
def password_reset_page(request):
    """Serve a página HTML de reset de password."""
    return render(request, 'reset_password.html')


# ── Login ──────────────────────────────────────────────────
class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        import traceback
        import logging
        logger = logging.getLogger(__name__)

        try:
            serializer = LoginSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            username = serializer.validated_data['username']
            password = serializer.validated_data['password']

            try:
                user = Users.objects.get(username=username)
            except Users.DoesNotExist:
                return Response({'detail': 'Credenciais inválidas.'}, status=status.HTTP_401_UNAUTHORIZED)

            if user.user_status != 1:
                return Response({'detail': 'Conta inativa.'}, status=status.HTTP_403_FORBIDDEN)

            if not check_password(password, user.password_hash):
                return Response({'detail': 'Credenciais inválidas.'}, status=status.HTTP_401_UNAUTHORIZED)

            try:
                LoginHistory.objects.create(
                    user=user,
                    login_ip=request.META.get('REMOTE_ADDR', '0.0.0.0'),
                    login_device=request.META.get('HTTP_USER_AGENT', 'unknown')[:45],
                    login_location='n/a',
                    login_status='success',
                )
            except Exception:
                pass  # histórico de login não deve bloquear o acesso

            tokens = _get_tokens(user)
            return Response({'user_id': user.user_id, 'username': user.username, **tokens})

        except Exception as exc:
            tb = traceback.format_exc()
            logger.error('LoginView 500: %s\n%s', exc, tb)
            return Response(
                {'detail': f'Erro interno: {type(exc).__name__}: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# ── Registo (só por convite) ───────────────────────────────
class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        d = serializer.validated_data
        username = d['username']
        email = d['email']
        password = d['password']
        full_name = d.get('full_name', username)
        invite_code = d.get('invite_code', '').strip().upper()

        if not invite_code:
            return Response(
                {'detail': 'Código de convite obrigatório para criar conta.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            from farms.models import FarmInvites
            invite = FarmInvites.objects.get(invite_code=invite_code, invite_status=0)
        except FarmInvites.DoesNotExist:
            return Response(
                {'detail': 'Código de convite inválido ou já utilizado.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if timezone.now() > invite.expires_at:
            invite.invite_status = 2
            invite.save(update_fields=['invite_status'])
            return Response(
                {'detail': 'Código de convite expirado. Pede um novo ao gestor.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if Users.objects.filter(username=username).exists():
            return Response({'detail': 'Username já existe.'}, status=status.HTTP_400_BAD_REQUEST)
        if Profiles.objects.filter(profile_email=email).exists():
            return Response({'detail': 'Email já registado.'}, status=status.HTTP_400_BAD_REQUEST)

        user = Users.objects.create(
            username=username,
            password_hash=make_password(password),
            user_status=1,
        )

        profile = Profiles.objects.create(
            user=user,
            profile_name=full_name,
            profile_email=email,
            profile_mobile=d.get('mobile', ''),
            created_by=user.user_id,
        )

        try:
            from farms.models import ProfilesHasFarms
            ProfilesHasFarms.objects.create(
                farm_id=invite.farm_id,
                profile_id=profile.profile_id,
                connection_date=timezone.now().date(),
                connection_role=invite.invite_role,
                connection_status=1,
                default_farm=1,
                created_by=user.user_id,
            )
            invite.invite_status = 1
            invite.used_at = timezone.now()
            invite.used_by = user.user_id
            invite.save(update_fields=['invite_status', 'used_at', 'used_by'])
        except Exception as e:
            print("ERRO AO ASSOCIAR FARM:", e)

        tokens = _get_tokens(user)
        return Response({
            'detail': 'Conta criada com sucesso.',
            'user_id': user.user_id,
            'username': user.username,
            **tokens,
        }, status=status.HTTP_201_CREATED)


# ── Me ─────────────────────────────────────────────────────
class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            return Response(MeSerializer(request.user).data)
        except Exception as e:
            # Fallback se o perfil ou algum campo falhar
            return Response({
                'user_id': request.user.user_id,
                'username': request.user.username,
                'user_status': request.user.user_status,
                'profile': None,
            })


# ── Refresh ────────────────────────────────────────────────
class RefreshView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response({'detail': 'Refresh token em falta.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            refresh = RefreshToken(refresh_token)
            return Response({'access': str(refresh.access_token)})
        except Exception:
            return Response({'detail': 'Token inválido ou expirado.'}, status=status.HTTP_401_UNAUTHORIZED)


# ── Logout ─────────────────────────────────────────────────
class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        return Response({'detail': 'Logout efetuado com sucesso.'}, status=status.HTTP_205_RESET_CONTENT)


# ── Password Reset — Pedir ─────────────────────────────────
class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '').strip()
        if not email:
            return Response({'detail': 'Email obrigatório.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            profile = Profiles.objects.get(profile_email=email, deleted_at__isnull=True)
            user = profile.user

            token = secrets.token_urlsafe(32)
            expire = timezone.now() + timedelta(hours=2)

            user.reset_token = token
            user.reset_expire = expire
            user.save(update_fields=['reset_token', 'reset_expire'])

            # Link para a página HTML que redireciona para a app
            reset_link = f"http://127.0.0.1:8000/reset-password/?token={token}&email={email}"

            send_mail(
                subject='Vision4Farms — Recuperação de Palavra-passe',
                message=(
                    f'Olá {profile.profile_name},\n\n'
                    f'Recebemos um pedido de recuperação de palavra-passe para a tua conta.\n\n'
                    f'Clica no link abaixo para definir uma nova palavra-passe:\n\n'
                    f'    {reset_link}\n\n'
                    f'Este link é válido durante 2 horas.\n\n'
                    f'Se não fizeste este pedido, ignora este email.\n\n'
                    f'Equipa Vision4Farms'
                ),
                from_email=None,
                recipient_list=[email],
                fail_silently=False,
            )
        except Profiles.DoesNotExist:
            pass

        return Response({
            'detail': 'Se o email existir na nossa base de dados, receberás instruções em breve.'
        })


# ── Password Reset — Confirmar ─────────────────────────────
class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token', '').strip()
        new_password = request.data.get('new_password', '')
        confirm_password = request.data.get('confirm_password', '')

        if not token or not new_password:
            return Response(
                {'detail': 'Token e nova password são obrigatórios.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if new_password != confirm_password:
            return Response({'detail': 'As passwords não coincidem.'}, status=status.HTTP_400_BAD_REQUEST)

        if len(new_password) < 6:
            return Response(
                {'detail': 'A password deve ter pelo menos 6 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            user = Users.objects.get(reset_token=token)
        except Users.DoesNotExist:
            return Response({'detail': 'Token inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        if user.reset_expire and timezone.now() > user.reset_expire:
            return Response(
                {'detail': 'Token expirado. Pede um novo.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user.password_hash = make_password(new_password)
        user.reset_token = None
        user.reset_expire = None
        user.save(update_fields=['password_hash', 'reset_token', 'reset_expire'])

        return Response({'detail': 'Password alterada com sucesso. Podes fazer login.'})


# ── Profile Update (PATCH) ────────────────────────────────
class ProfileUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request):
        try:
            profile = Profiles.objects.get(user=request.user, deleted_at__isnull=True)
        except Profiles.DoesNotExist:
            return Response({'detail': 'Perfil não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        serializer = ProfileUpdateSerializer(profile, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        serializer.save(updated_by=request.user.user_id, updated_at=timezone.now())
        return Response(ProfileSerializer(profile).data)


# ── Profile Picture Upload ─────────────────────────────────
class ProfilePictureUploadView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        try:
            profile = Profiles.objects.get(user=request.user, deleted_at__isnull=True)
        except Profiles.DoesNotExist:
            return Response({'detail': 'Perfil não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        picture = request.FILES.get('picture')
        if not picture:
            return Response({'detail': 'Ficheiro obrigatório.'}, status=status.HTTP_400_BAD_REQUEST)

        ext = os.path.splitext(picture.name)[1].lower()
        if ext not in ('.jpg', '.jpeg', '.png', '.webp'):
            return Response({'detail': 'Formato inválido. Usa JPG, PNG ou WebP.'},
                            status=status.HTTP_400_BAD_REQUEST)

        upload_dir = os.path.join(settings.MEDIA_ROOT, 'profile_pictures', str(profile.profile_id))
        os.makedirs(upload_dir, exist_ok=True)

        filename = f'{uuid.uuid4().hex}{ext}'
        filepath = os.path.join(upload_dir, filename)
        with open(filepath, 'wb+') as dest:
            for chunk in picture.chunks():
                dest.write(chunk)

        relative_path = f'profile_pictures/{profile.profile_id}/{filename}'
        profile.profile_picture = relative_path
        profile.updated_by = request.user.user_id
        profile.updated_at = timezone.now()
        profile.save(update_fields=['profile_picture', 'updated_by', 'updated_at'])

        return Response(ProfileSerializer(profile).data)


# ── Change Password (autenticado) ──────────────────────────
class PasswordChangeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        current_password = request.data.get('current_password', '')
        new_password = request.data.get('new_password', '')
        confirm_password = request.data.get('confirm_password', '')

        if not current_password or not new_password:
            return Response({'detail': 'Todos os campos são obrigatórios.'},
                            status=status.HTTP_400_BAD_REQUEST)

        if not check_password(current_password, request.user.password_hash):
            return Response({'detail': 'Password atual incorreta.'},
                            status=status.HTTP_400_BAD_REQUEST)

        if new_password != confirm_password:
            return Response({'detail': 'As novas passwords não coincidem.'},
                            status=status.HTTP_400_BAD_REQUEST)

        if len(new_password) < 6:
            return Response({'detail': 'A nova password deve ter pelo menos 6 caracteres.'},
                            status=status.HTTP_400_BAD_REQUEST)

        request.user.password_hash = make_password(new_password)
        request.user.save(update_fields=['password_hash'])

        return Response({'detail': 'Password alterada com sucesso.'})