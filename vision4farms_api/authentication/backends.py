"""
Backend JWT custom — usa a tabela 'users' própria.
Não depende de django.contrib.auth.
"""
import hashlib
import hmac
import base64
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed
from .models import Users


class CustomJWTAuthentication(JWTAuthentication):
    """
    Sobrescreve get_user para carregar o utilizador da tabela 'users'
    em vez de django.contrib.auth.models.User.
    """

    def get_user(self, validated_token):
        try:
            user_id = validated_token['user_id']
        except KeyError:
            raise InvalidToken('Token sem user_id.')

        try:
            user = Users.objects.get(user_id=user_id, user_status=1)
        except Users.DoesNotExist:
            raise AuthenticationFailed('Utilizador não encontrado ou inativo.')

        return user
