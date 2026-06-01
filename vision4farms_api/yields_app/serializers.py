from django.utils.text import slugify
from rest_framework import serializers
from .models import Yields, YieldsAnalysis, YieldsHarvests
from activities.models import Activities, Observations
from crops.models import Crops, CropsVarieties
from lands.models import Lands


YIELD_NUTRIENT_FIELDS = [
    'yield_analysis_nitrogen_total', 'yield_analysis_phosphorus',
    'yield_analysis_potassium', 'yield_analysis_calcium',
    'yield_analysis_magnesium', 'yield_analysis_sulfur',
    'yield_analysis_iron', 'yield_analysis_manganese',
    'yield_analysis_boro', 'yield_analysis_cobre',
    'yield_analysis_zinc', 'yield_analysis_molybdenum',
    'yield_analysis_sodium', 'yield_analysis_aluminum',
]

HARVEST_FIELDS = [
    'harvest_date', 'harvest_name', 'harvest_harvested', 'unit_measurement',
    'harvested_labor_count', 'harvested_labor_hours',
    'harvested_labor_hours_per_operator', 'harvested_labor_total_cost',
    'harvest_kg_per_operator', 'harvested_machine_count',
    'harvested_machine_hours', 'harvested_machine_cost',
    'total_harvest_cost', 'harvest_cost_per_kg', 'harvest_kg_per_hour',
]


class YieldListSerializer(serializers.ModelSerializer):
    crop_name = serializers.SerializerMethodField()
    variety_name = serializers.SerializerMethodField()
    land_name = serializers.SerializerMethodField()
    activity_count = serializers.SerializerMethodField()
    last_irrigation = serializers.SerializerMethodField()

    class Meta:
        model = Yields
        fields = [
            'yield_id', 'farm_id', 'land_id', 'crop_id', 'variety_id',
            'yield_name', 'yield_method', 'yield_size', 'yield_status', 'created_at',
            'crop_name', 'variety_name', 'land_name', 'activity_count', 'last_irrigation',
        ]

    def _crop(self, crop_id):
        if not crop_id:
            return None
        return Crops.objects.filter(crop_id=crop_id, deleted_at__isnull=True).first()

    def _variety(self, variety_id):
        if not variety_id:
            return None
        return CropsVarieties.objects.filter(
            variety_id=variety_id,
            deleted_at__isnull=True,
        ).first()

    def _land(self, land_id):
        if not land_id:
            return None
        return Lands.objects.filter(land_id=land_id, deleted_at__isnull=True).first()

    def get_crop_name(self, obj):
        crop = self._crop(obj.crop_id)
        return crop.crop_name if crop else None

    def get_variety_name(self, obj):
        variety = self._variety(obj.variety_id)
        return variety.variety_name if variety else None

    def get_land_name(self, obj):
        land = self._land(obj.land_id)
        return land.land_name if land else None

    def get_activity_count(self, obj):
        return Activities.objects.filter(
            yield_id=obj.yield_id,
            deleted_at__isnull=True,
        ).count()

    def get_last_irrigation(self, obj):
        irrigation = (
            Activities.objects
            .filter(
                yield_id=obj.yield_id,
                activity_type='irrigation',
                deleted_at__isnull=True,
            )
            .order_by('-activity_date_done', '-activity_date_planned')
            .first()
        )
        if not irrigation:
            return None
        return irrigation.activity_date_done or irrigation.activity_date_planned


class YieldDetailSerializer(YieldListSerializer):
    lands = serializers.SerializerMethodField()
    activities = serializers.SerializerMethodField()
    observations = serializers.SerializerMethodField()

    class Meta(YieldListSerializer.Meta):
        fields = YieldListSerializer.Meta.fields + [
            'yield_notes', 'yield_estimated', 'yield_unit',
            'lands', 'activities', 'observations',
        ]

    def get_lands(self, obj):
        land = Lands.objects.filter(land_id=obj.land_id, deleted_at__isnull=True).first()
        if not land:
            return []
        return [{
            'land_id': land.land_id,
            'land_name': land.land_name,
            'land_size': float(land.land_size) if land.land_size is not None else None,
        }]

    def get_activities(self, obj):
        activities = (
            Activities.objects
            .filter(yield_id=obj.yield_id, deleted_at__isnull=True)
            .order_by('-activity_date_planned')[:20]
        )
        data = []
        for a in activities:
            data.append({
                'activity_id': a.activity_id,
                'activity_name': a.activity_name,
                'activity_type': a.activity_type,
                'activity_status': a.activity_status,
                'activity_priority': a.activity_priority,
                'activity_date_planned': a.activity_date_planned,
                'activity_date_done': a.activity_date_done,
            })
        return data

    def get_observations(self, obj):
        observations = (
            Observations.objects
            .filter(yield_id=obj.yield_id, deleted_at__isnull=True)
            .order_by('-created_at')[:20]
        )
        land_name = self.get_land_name(obj)
        crop_name = self.get_crop_name(obj)
        data = []
        for o in observations:
            data.append({
                'observation_id': o.observation_id,
                'observation_text': o.observation_text,
                'created_at': o.created_at,
                'land_name': land_name,
                'crop_name': crop_name,
            })
        return data


class YieldCreateSerializer(serializers.ModelSerializer):
    farm    = serializers.IntegerField(write_only=True)
    land    = serializers.IntegerField(write_only=True)
    crop    = serializers.IntegerField(write_only=True)
    variety = serializers.IntegerField(write_only=True, required=False, allow_null=True)

    class Meta:
        model = Yields
        fields = [
            'farm', 'land', 'crop', 'variety',
            'yield_name', 'yield_method', 'yield_size',
            'yield_estimated', 'yield_unit', 'yield_notes',
        ]

    def create(self, validated_data):
        request  = self.context.get('request')
        user_id  = request.user.user_id if request else 1
        name     = validated_data.get('yield_name', 'Cultura')

        return Yields.objects.create(
            farm_id    = validated_data['farm'],
            land_id    = validated_data['land'],
            crop_id    = validated_data['crop'],
            variety_id = validated_data.get('variety'),
            yield_name = name,
            yield_slug = slugify(name),
            yield_method    = validated_data.get('yield_method', 'convencional'),
            yield_size      = validated_data.get('yield_size', 0),
            yield_estimated = validated_data.get('yield_estimated'),
            yield_unit      = validated_data.get('yield_unit'),
            yield_notes     = validated_data.get('yield_notes'),
            yield_status    = 1,
            created_by      = user_id,
        )


class YieldAnalysisSerializer(serializers.ModelSerializer):
    yield_id = serializers.IntegerField(source='yield_field.yield_id', read_only=True)

    class Meta:
        model = YieldsAnalysis
        exclude = ['yield_field']


class HarvestSerializer(serializers.ModelSerializer):
    yield_id = serializers.IntegerField(source='yield_field.yield_id', read_only=True)

    class Meta:
        model = YieldsHarvests
        exclude = ['yield_field']
