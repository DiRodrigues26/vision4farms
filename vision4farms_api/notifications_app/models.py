from django.db import models
from authentication.models import Users


class Notifications(models.Model):
    notification_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, related_name='notifications')
    farm_id = models.IntegerField(blank=True, null=True)
    land_id = models.IntegerField(blank=True, null=True)
    activity_id = models.IntegerField(blank=True, null=True)
    agenda_id = models.IntegerField(blank=True, null=True)
    observation_id = models.IntegerField(blank=True, null=True)
    crop_id = models.IntegerField(blank=True, null=True)
    notification_type = models.CharField(max_length=50)
    notification_title = models.CharField(max_length=150)
    notification_body = models.TextField()
    notification_read = models.IntegerField(default=0)
    notification_read_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    deleted_by = models.IntegerField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'notifications'

    def __str__(self):
        return self.notification_title


class FcmTokens(models.Model):
    token_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, models.DO_NOTHING, related_name='fcm_tokens')
    token = models.CharField(max_length=255, unique=True)
    device = models.CharField(max_length=45, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'fcm_tokens'

    def __str__(self):
        return f'{self.token[:20]}… ({self.user_id})'


class NotificationPreferences(models.Model):
    pref_id = models.AutoField(primary_key=True)
    user = models.OneToOneField(Users, models.DO_NOTHING, related_name='notification_preferences')
    notify_activity = models.IntegerField(default=1)
    notify_agenda = models.IntegerField(default=1)
    notify_observation = models.IntegerField(default=1)
    notify_irrigation = models.IntegerField(default=1)
    notify_system = models.IntegerField(default=1)
    reminder_hours = models.DecimalField(max_digits=6, decimal_places=2, default=24.00)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'notification_preferences'

    def __str__(self):
        return f'Prefs user {self.user_id}'
