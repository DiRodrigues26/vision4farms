from rest_framework.permissions import BasePermission

from .models import ProfilesHasFarms

ROLE_GESTOR = 1
ROLE_COLABORADOR = 2
ROLE_CONSULTOR = 3


def _extract_farm_id(request, view):
    """Extrai farm_id de kwargs, query params ou body."""
    farm_id = view.kwargs.get('farm_id')
    if farm_id:
        return int(farm_id)
    farm_id = request.query_params.get('farm_id')
    if farm_id:
        return int(farm_id)
    farm_id = request.data.get('farm') or request.data.get('farm_id')
    if farm_id:
        return int(farm_id)
    return None


def _get_user_role(user, farm_id):
    """Devolve o role do utilizador numa farm, ou None se não tiver acesso."""
    try:
        phf = ProfilesHasFarms.objects.get(
            profile_id=user.profile.profile_id,
            farm_id=farm_id,
            connection_status=1,
            deleted_at__isnull=True,
        )
        return phf.connection_role
    except ProfilesHasFarms.DoesNotExist:
        return None


class IsFarmMember(BasePermission):
    """Permite acesso se o utilizador pertence à exploração."""
    message = 'Não tem acesso a esta exploração.'

    def has_permission(self, request, view):
        farm_id = _extract_farm_id(request, view)
        if farm_id is None:
            return True  # sem farm_id no request, deixar a view tratar
        return _get_user_role(request.user, farm_id) is not None


class IsGestorOrReadOnly(BasePermission):
    """Leitura para todos os membros. Escrita apenas para Gestores."""
    message = 'Apenas gestores podem realizar esta ação.'

    def has_permission(self, request, view):
        farm_id = _extract_farm_id(request, view)
        if farm_id is None:
            return True

        role = _get_user_role(request.user, farm_id)
        if role is None:
            return False

        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True

        return role == ROLE_GESTOR


class IsOwnerOrGestor(BasePermission):
    """Permite escrita se o utilizador é Gestor ou criou o objeto."""
    message = 'Apenas gestores ou o criador podem alterar este registo.'

    def has_object_permission(self, request, view, obj):
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True

        farm_id = _extract_farm_id(request, view)
        if farm_id is None:
            farm_id = getattr(obj, 'farm_id', None)

        role = _get_user_role(request.user, farm_id) if farm_id else None

        if role == ROLE_GESTOR:
            return True

        created_by = getattr(obj, 'created_by', None)
        return created_by is not None and created_by == request.user.user_id
