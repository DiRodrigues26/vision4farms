from rest_framework import serializers
from .models import Agenda


class AgendaSerializer(serializers.ModelSerializer):
    land_name = serializers.CharField(source='land.land_name', read_only=True, default=None)
    agenda_type_display = serializers.CharField(
        source='get_agenda_type_display', read_only=True
    )
    agenda_status_display = serializers.CharField(
        source='get_agenda_status_display', read_only=True
    )

    class Meta:
        model = Agenda
        fields = [
            'agenda_id', 'farm', 'land', 'land_name', 'yield_id', 'activity_id',
            'user_id', 'agenda_title', 'agenda_description',
            'agenda_type', 'agenda_type_display',
            'agenda_date', 'agenda_time_start', 'agenda_time_end', 'agenda_allday',
            'recurrence', 'recurrence_end',
            'agenda_status', 'agenda_status_display',
            'agenda_notes', 'created_at',
        ]
        read_only_fields = ['agenda_id', 'created_at']


class AgendaCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Agenda
        fields = [
            'farm', 'land', 'yield_id', 'activity_id',
            'agenda_title', 'agenda_description', 'agenda_type',
            'agenda_date', 'agenda_time_start', 'agenda_time_end', 'agenda_allday',
            'recurrence', 'recurrence_end', 'agenda_notes',
        ]

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        agenda = Agenda.objects.create(
            created_by=user_id,
            user_id=user_id,
            **validated_data,
        )

        # Criar notificação para o utilizador
        from notifications_app.models import Notifications
        farm = validated_data.get('farm')
        Notifications.objects.create(
            user=request.user,
            farm_id=farm.farm_id if farm else None,
            agenda_id=agenda.agenda_id,
            notification_type='agenda',
            notification_title='Novo evento na agenda',
            notification_body=f'Evento "{agenda.agenda_title}" criado para {agenda.agenda_date}',
        )

        return agenda
