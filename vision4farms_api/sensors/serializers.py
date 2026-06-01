from rest_framework import serializers

from lands.models import Lands
from .models import SensorNodeAssociation


class SensorNodeAssociationSerializer(serializers.ModelSerializer):
    land_name = serializers.SerializerMethodField()

    class Meta:
        model = SensorNodeAssociation
        fields = [
            'association_id',
            'farm_id',
            'land_id',
            'land_name',
            'gateway_code',
            'sensor_firebase_id',
            'sensor_no_id',
            'sensor_nome',
            'sensor_tipo',
            'sensor_status',
            'ultimo_contacto',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['association_id', 'created_at', 'updated_at']

    def get_land_name(self, obj):
        try:
            return Lands.objects.get(
                land_id=obj.land_id,
                deleted_at__isnull=True,
            ).land_name
        except Lands.DoesNotExist:
            return ''


class SensorAssociationInputSerializer(serializers.Serializer):
    land_id = serializers.IntegerField()
    gateway_code = serializers.CharField(max_length=45)
    sensor_firebase_id = serializers.CharField(max_length=120)
    sensor_no_id = serializers.CharField(
        max_length=45,
        required=False,
        allow_blank=True,
        allow_null=True,
    )
    sensor_nome = serializers.CharField(max_length=120)
    sensor_tipo = serializers.CharField(
        max_length=45,
        required=False,
        allow_blank=True,
        allow_null=True,
    )
    sensor_status = serializers.CharField(
        max_length=45,
        required=False,
        allow_blank=True,
        allow_null=True,
    )
    ultimo_contacto = serializers.CharField(
        max_length=45,
        required=False,
        allow_blank=True,
        allow_null=True,
    )


class SensorAssociationBulkSerializer(serializers.Serializer):
    farm_id = serializers.IntegerField()
    associations = SensorAssociationInputSerializer(many=True)
