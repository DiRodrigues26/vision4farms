from django.db import models


class Users(models.Model):
    """
    Tabela de utilizadores própria (managed=False).
    passwords guardadas com werkzeug pbkdf2:sha256.
    """
    user_id = models.AutoField(primary_key=True)
    username = models.CharField(unique=True, max_length=90)
    password_hash = models.CharField(max_length=255)
    reset_token = models.CharField(max_length=120, blank=True, null=True)
    reset_expire = models.DateTimeField(blank=True, null=True)
    user_status = models.IntegerField(default=1)

    class Meta:
        managed = False
        db_table = 'users'

    def __str__(self):
        return self.username

    # ── Compatibilidade mínima esperada pelo DRF ──────────
    @property
    def is_authenticated(self):
        return True

    @property
    def pk(self):
        return self.user_id


class Profiles(models.Model):
    profile_id = models.AutoField(primary_key=True)
    profile_name = models.CharField(max_length=150)
    profile_nif = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_nifap = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_cardfit = models.CharField(unique=True, max_length=9, blank=True, null=True)
    profile_picture = models.TextField(blank=True, null=True)
    profile_email = models.CharField(unique=True, max_length=90)
    profile_mobile = models.CharField(max_length=13, blank=True, null=True)
    profile_phone = models.CharField(max_length=13, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.IntegerField()
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)
    updated_by = models.IntegerField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)
    user = models.OneToOneField(
        Users,
        models.DO_NOTHING,
        related_name='profile'
    )

    class Meta:
        managed = False
        db_table = 'profiles'

    def __str__(self):
        return self.profile_name


class LoginHistory(models.Model):
    login_id = models.AutoField(primary_key=True)
    login_ip = models.CharField(max_length=45)
    login_device = models.CharField(max_length=45)
    login_location = models.CharField(max_length=45)
    login_status = models.CharField(max_length=45)
    created_at = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'login_history'
