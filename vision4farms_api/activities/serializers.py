from django.utils import timezone
from django.utils.text import slugify
import re
from rest_framework import serializers
from .models import Activities, Observations


class ObservationSerializer(serializers.ModelSerializer):
    land_name = serializers.CharField(source='land.land_name', read_only=True)
    crop_name = serializers.SerializerMethodField()
    yield_name = serializers.SerializerMethodField()

    class Meta:
        model = Observations
        fields = [
            'observation_id', 'farm', 'land', 'land_name', 'yield_id',
            'crop_name', 'yield_name',
            'observation_text', 'observation_photo', 'observation_gps',
            'estado_fenologico', 'numero_armadilha', 'qt_detetada',
            'praga_fungo', 'created_at',
        ]
        read_only_fields = [
            'observation_id', 'created_at', 'land_name',
            'crop_name', 'yield_name',
        ]

    def _get_yield(self, obj):
        if not obj.yield_id:
            return None
        from yields_app.models import Yields
        return Yields.objects.filter(
            yield_id=obj.yield_id,
            deleted_at__isnull=True,
        ).first()

    def get_yield_name(self, obj):
        y = self._get_yield(obj)
        return y.yield_name if y else None

    def get_crop_name(self, obj):
        y = self._get_yield(obj)
        if not y or not y.crop_id:
            return None
        from crops.models import Crops
        crop = Crops.objects.filter(crop_id=y.crop_id).first()
        return crop.crop_name if crop else None

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        obs = Observations.objects.create(created_by=user_id, **validated_data)

        from notifications_app.models import Notifications
        farm = validated_data.get('farm')
        land = validated_data.get('land')
        Notifications.objects.create(
            user=request.user,
            farm_id=farm.farm_id if farm else None,
            land_id=land.land_id if land else None,
            observation_id=obs.observation_id,
            notification_type='observation',
            notification_title='Nova observação registada',
            notification_body=f'Observação criada{f" no terreno {land.land_name}" if land else ""}',
        )
        return obs


class ActivitySerializer(serializers.ModelSerializer):
    observation = ObservationSerializer(read_only=True)
    land_name = serializers.CharField(source='land.land_name', read_only=True)
    yield_name = serializers.SerializerMethodField()
    activity_time_planned = serializers.SerializerMethodField()
    activity_status_display = serializers.CharField(
        source='get_activity_status_display', read_only=True
    )
    activity_priority_display = serializers.CharField(
        source='get_activity_priority_display', read_only=True
    )

    class Meta:
        model = Activities
        fields = [
            'activity_id', 'farm', 'land', 'yield_id', 'user_id',
            'land_name', 'yield_name',
            'observation', 'activity_name', 'activity_slug', 'activity_type',
            'activity_description', 'activity_date_planned', 'activity_date_done',
            'activity_time_planned',
            'activity_status', 'activity_status_display',
            'activity_priority', 'activity_priority_display',
            'activity_anomaly', 'activity_anomaly_desc', 'activity_notes',
            'created_at',
        ]

    def get_activity_time_planned(self, obj):
        notes = obj.activity_notes or ''
        m = re.search(r'\[hora_planeada:(\d{2}:\d{2})\]', notes)
        return m.group(1) if m else None

    def get_yield_name(self, obj):
        if not obj.yield_id:
            return None
        from .models import Yields
        y = Yields.objects.filter(
            yield_id=obj.yield_id,
            deleted_at__isnull=True,
        ).first()
        return y.yield_name if y else None


class ActivityCreateSerializer(serializers.ModelSerializer):
    activity_time_planned = serializers.CharField(
        write_only=True, required=False, allow_blank=True
    )

    class Meta:
        model = Activities
        fields = [
            'farm', 'land', 'yield_id', 'observation',
            'activity_name', 'activity_type', 'activity_description',
            'activity_date_planned', 'activity_status', 'activity_priority',
            'activity_notes', 'activity_time_planned',
        ]

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        name = validated_data['activity_name']
        time_planned = validated_data.pop('activity_time_planned', '').strip()
        notes = validated_data.get('activity_notes') or ''
        if time_planned:
            marker = f'[hora_planeada:{time_planned}]'
            validated_data['activity_notes'] = f'{marker} {notes}'.strip()
        activity = Activities.objects.create(
            activity_slug=slugify(name),
            created_by=user_id,
            user_id=user_id,
            updated_at=timezone.now(),
            **validated_data
        )

        from notifications_app.models import Notifications
        farm = validated_data.get('farm')
        land = validated_data.get('land')
        date_planned = validated_data.get('activity_date_planned')
        date_str = date_planned.strftime('%d/%m/%Y') if date_planned else ''
        Notifications.objects.create(
            user=request.user,
            farm_id=farm.farm_id if farm else None,
            land_id=land.land_id if land else None,
            activity_id=activity.activity_id,
            notification_type='activity',
            notification_title='Nova atividade agendada',
            notification_body=f'"{name}" agendada para {date_str}',
        )
        return activity
