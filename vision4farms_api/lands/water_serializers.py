from django.utils import timezone
from django.utils.text import slugify
from rest_framework import serializers
from .models import (
    WaterSource,
    WaterSourceType,
    WaterIrrigationMethod,
    WaterUsageLog,
    WaterIrrigationPlanned,
)


# ── Lookups ──────────────────────────────────────────────────

class WaterSourceTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterSourceType
        fields = ['water_type_id', 'water_type_name']


class WaterIrrigationMethodSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterIrrigationMethod
        fields = ['water_irrigation_id', 'water_irrigation_name']


# ── Water Source ─────────────────────────────────────────────

class WaterSourceSerializer(serializers.ModelSerializer):
    water_type_name = serializers.SerializerMethodField()

    class Meta:
        model = WaterSource
        fields = [
            'water_source_id', 'farm_id', 'water_source_name', 'water_source_slug',
            'water_type_id', 'water_type_name',
            'water_source_location_description',
            'water_source_latitude', 'water_source_longitude',
            'water_source_depth_meters', 'water_source_capacity',
            'water_source_notes', 'water_source_ownership', 'water_source_has_costs',
            'water_source_build_date', 'water_source_build_cost',
            'water_source_build_invoice', 'water_source_status',
            'created_at',
        ]

    def get_water_type_name(self, obj):
        try:
            return WaterSourceType.objects.get(water_type_id=obj.water_type_id).water_type_name
        except WaterSourceType.DoesNotExist:
            return None


class WaterSourceWriteSerializer(serializers.ModelSerializer):
    water_source_build_invoice = serializers.CharField(
        required=False, allow_blank=True, allow_null=True, default=''
    )

    class Meta:
        model = WaterSource
        fields = [
            'farm_id', 'water_source_name', 'water_type_id',
            'water_source_location_description',
            'water_source_latitude', 'water_source_longitude',
            'water_source_depth_meters', 'water_source_capacity',
            'water_source_notes', 'water_source_ownership', 'water_source_has_costs',
            'water_source_build_date', 'water_source_build_cost',
            'water_source_build_invoice', 'water_source_status',
        ]

    def validate_water_source_build_invoice(self, value):
        return value or ''

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        name = validated_data['water_source_name']
        return WaterSource.objects.create(
            water_source_slug=slugify(name),
            created_at=timezone.now(),
            created_by=user_id,
            **validated_data,
        )

    def update(self, instance, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        if 'water_source_name' in validated_data:
            validated_data['water_source_slug'] = slugify(validated_data['water_source_name'])
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.updated_at = timezone.now()
        instance.updated_by = user_id
        instance.save()
        return instance


# ── Water Usage Log ──────────────────────────────────────────

class WaterUsageLogSerializer(serializers.ModelSerializer):
    method_name = serializers.SerializerMethodField()

    class Meta:
        model = WaterUsageLog
        fields = [
            'water_usage_id', 'water_source_id', 'land_id',
            'water_usage_usage_date', 'water_usage_volume_liters',
            'water_usage_cost', 'water_usage_method', 'method_name',
            'water_usage_purpose', 'water_usage_notes',
            'created_at',
        ]

    def get_method_name(self, obj):
        if not obj.water_usage_method:
            return None
        try:
            return WaterIrrigationMethod.objects.get(
                water_irrigation_id=obj.water_usage_method
            ).water_irrigation_name
        except WaterIrrigationMethod.DoesNotExist:
            return None


class WaterUsageLogWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterUsageLog
        fields = [
            'water_source_id', 'land_id',
            'water_usage_usage_date', 'water_usage_volume_liters',
            'water_usage_cost', 'water_usage_method',
            'water_usage_purpose', 'water_usage_notes',
        ]

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        return WaterUsageLog.objects.create(
            created_at=timezone.now(),
            created_by=user_id,
            **validated_data,
        )

    def update(self, instance, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.updated_at = timezone.now()
        instance.updated_by = user_id
        instance.save()
        return instance


# ── Water Irrigation Planned ─────────────────────────────────

class WaterIrrigationPlannedSerializer(serializers.ModelSerializer):
    method_name = serializers.SerializerMethodField()

    class Meta:
        model = WaterIrrigationPlanned
        fields = [
            'planned_id', 'farm_id', 'land_id', 'water_source_id', 'yield_id',
            'planned_date', 'planned_time', 'planned_duration_min',
            'planned_volume_liters', 'irrigation_method', 'method_name',
            'irrigation_status', 'executed_at', 'water_usage_id',
            'planned_notes', 'created_at',
        ]

    def get_method_name(self, obj):
        if not obj.irrigation_method:
            return None
        try:
            return WaterIrrigationMethod.objects.get(
                water_irrigation_id=obj.irrigation_method
            ).water_irrigation_name
        except WaterIrrigationMethod.DoesNotExist:
            return None


class WaterIrrigationPlannedWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = WaterIrrigationPlanned
        fields = [
            'farm_id', 'land_id', 'water_source_id', 'yield_id',
            'planned_date', 'planned_time', 'planned_duration_min',
            'planned_volume_liters', 'irrigation_method', 'irrigation_status',
            'planned_notes',
        ]

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        return WaterIrrigationPlanned.objects.create(
            created_at=timezone.now(),
            created_by=user_id,
            **validated_data,
        )

    def update(self, instance, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.updated_at = timezone.now()
        instance.updated_by = user_id
        instance.save()
        return instance
