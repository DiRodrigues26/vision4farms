"""Signals do app notifications.

Sempre que uma `Notifications` é criada, dispara automaticamente uma push
notification via FCM para o utilizador. Assim qualquer sítio do código que
crie notificações (Sensor alerts, reminders, agenda, atividades, etc.)
fica coberto sem precisar de mudar nada.
"""
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver

from .fcm import send_push_to_user
from .models import Notifications

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Notifications)
def push_on_notification_create(sender, instance, created, **kwargs):
    if not created:
        return
    try:
        data = {
            'type': instance.notification_type or '',
            'notification_id': str(instance.notification_id),
        }
        if instance.farm_id:
            data['farm_id'] = str(instance.farm_id)
        if instance.land_id:
            data['land_id'] = str(instance.land_id)
        if instance.activity_id:
            data['activity_id'] = str(instance.activity_id)
        if instance.agenda_id:
            data['agenda_id'] = str(instance.agenda_id)
        if instance.observation_id:
            data['observation_id'] = str(instance.observation_id)

        send_push_to_user(
            user_id=instance.user_id,
            title=instance.notification_title,
            body=instance.notification_body,
            data=data,
        )
    except Exception as e:
        logger.error('Erro a enviar push para notificação %s: %s',
                     instance.notification_id, e)
