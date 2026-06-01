from rest_framework import serializers
from .models import Users, Profiles


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=90)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, min_length=6)
    full_name = serializers.CharField(max_length=150, required=False)
    mobile = serializers.CharField(max_length=13, required=False, allow_blank=True)
    invite_code = serializers.CharField(max_length=8, required=True)

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({'confirm_password': 'As passwords não coincidem.'})
        return attrs


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profiles
        fields = [
            'profile_id', 'profile_name', 'profile_email',
            'profile_mobile', 'profile_phone', 'profile_picture',
            'profile_nif', 'profile_nifap', 'profile_cardfit',
        ]


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = Users
        fields = ['user_id', 'username', 'user_status']


class ProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profiles
        fields = [
            'profile_name', 'profile_email', 'profile_mobile',
            'profile_phone', 'profile_nif', 'profile_nifap',
            'profile_cardfit',
        ]
        extra_kwargs = {f: {'required': False} for f in fields}


class MeSerializer(serializers.ModelSerializer):
    profile = ProfileSerializer(read_only=True)

    class Meta:
        model = Users
        fields = ['user_id', 'username', 'user_status', 'profile']