from datetime import timedelta

from django.utils import timezone
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import serializers

from farms.permissions import _get_user_role
from .models import Notifications, NotificationPreferences, FcmTokens


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notifications
        fields = [
            'notification_id', 'notification_type', 'notification_title',
            'notification_body', 'notification_read', 'notification_read_at',
            'farm_id', 'land_id', 'activity_id', 'agenda_id',
            'observation_id', 'created_at',
        ]


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notifications.objects.filter(
            user=self.request.user,
            deleted_at__isnull=True
        ).order_by('-created_at')


class NotificationMarkReadView(APIView):
    """Marca uma notificação como lida."""

    def patch(self, request, pk):
        try:
            n = Notifications.objects.get(
                notification_id=pk, user=request.user
            )
            n.notification_read = 1
            n.notification_read_at = timezone.now()
            n.save(update_fields=['notification_read', 'notification_read_at'])
            return Response({'detail': 'Marcada como lida.'})
        except Notifications.DoesNotExist:
            return Response({'detail': 'Não encontrada.'}, status=status.HTTP_404_NOT_FOUND)


class NotificationToggleReadView(APIView):
    """Alterna o estado lido/não lido de uma notificação."""

    def patch(self, request, pk):
        try:
            n = Notifications.objects.get(
                notification_id=pk, user=request.user
            )
            if n.notification_read == 1:
                n.notification_read = 0
                n.notification_read_at = None
            else:
                n.notification_read = 1
                n.notification_read_at = timezone.now()
            n.save(update_fields=['notification_read', 'notification_read_at'])
            return Response(NotificationSerializer(n).data)
        except Notifications.DoesNotExist:
            return Response({'detail': 'Não encontrada.'}, status=status.HTTP_404_NOT_FOUND)


class SensorAlertSerializer(serializers.Serializer):
    farm_id = serializers.IntegerField()
    land_id = serializers.IntegerField(required=False, allow_null=True)
    alert_key = serializers.CharField(max_length=120)
    title = serializers.CharField(max_length=150)
    body = serializers.CharField()


class SensorAlertNotificationView(APIView):
    """POST /api/notifications/sensor-alert/

    Cria uma notificação de praga/anomalia para o utilizador autenticado.
    Faz deduplicação: se já existir notificação com o mesmo alert_key
    (via notification_body começando com '[alert_key]') nos últimos 30 min,
    não cria nova.
    """

    def post(self, request):
        serializer = SensorAlertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        farm_id = data['farm_id']
        if _get_user_role(request.user, farm_id) is None:
            return Response(
                {'detail': 'Não tem acesso a esta exploração.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        alert_key = data['alert_key']
        body_with_key = f'[{alert_key}] {data["body"]}'
        cutoff = timezone.now() - timedelta(minutes=30)
        existing = Notifications.objects.filter(
            user=request.user,
            notification_type='sensor_alert',
            notification_body__startswith=f'[{alert_key}]',
            created_at__gte=cutoff,
            deleted_at__isnull=True,
        ).first()
        if existing:
            return Response(
                NotificationSerializer(existing).data,
                status=status.HTTP_200_OK,
            )

        notification = Notifications.objects.create(
            user=request.user,
            farm_id=farm_id,
            land_id=data.get('land_id'),
            notification_type='sensor_alert',
            notification_title=data['title'],
            notification_body=body_with_key,
            notification_read=0,
        )
        return Response(
            NotificationSerializer(notification).data,
            status=status.HTTP_201_CREATED,
        )


class FcmTokenRegisterView(APIView):
    """POST /api/notifications/devices/  — regista (ou actualiza) um token FCM
    para o utilizador autenticado."""

    def post(self, request):
        token = (request.data.get('token') or '').strip()
        device = (request.data.get('device') or '').strip() or None
        if not token:
            return Response(
                {'detail': 'token é obrigatório.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        obj, created = FcmTokens.objects.update_or_create(
            token=token,
            defaults={
                'user': request.user,
                'device': device,
            },
        )
        return Response(
            {
                'token_id': obj.token_id,
                'token': obj.token,
                'device': obj.device,
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class FcmTokenDeleteView(APIView):
    """DELETE /api/notifications/devices/<token>/ — remove o token actual
    (usado ao logout)."""

    def delete(self, request, token):
        FcmTokens.objects.filter(
            user=request.user,
            token=token,
        ).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class NotificationPreferencesSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationPreferences
        fields = [
            'notify_activity', 'notify_agenda', 'notify_observation',
            'notify_irrigation', 'notify_system', 'reminder_hours',
        ]


class NotificationPreferencesView(APIView):
    """GET — devolve preferências do user (cria defaults se não existir).
       PATCH — atualiza preferências."""

    def get(self, request):
        prefs, _ = NotificationPreferences.objects.get_or_create(user=request.user)
        return Response(NotificationPreferencesSerializer(prefs).data)

    def patch(self, request):
        prefs, _ = NotificationPreferences.objects.get_or_create(user=request.user)
        ser = NotificationPreferencesSerializer(prefs, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)
