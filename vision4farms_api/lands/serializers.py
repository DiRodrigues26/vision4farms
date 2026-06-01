from django.utils import timezone
from django.utils.text import slugify
from rest_framework import serializers
from .models import Lands, LandsSoilAnalysis, WaterUsageLog


SOIL_NUTRIENT_FIELDS = [
    'soil_analysis_ph_h20', 'soil_analysis_acidifier', 'soil_analysis_ph_cacl2',
    'soil_analysis_conductivity', 'soil_analysis_organic_matter',
    'soil_analysis_total_nitrogen', 'soil_analysis_carbon_nitrogen',
    'soil_analysis_phosphor', 'soil_analysis_potassium', 'soil_analysis_calcium',
    'soil_analysis_magnesium', 'soil_analysis_sulfur', 'soil_analysis_iron',
    'soil_analysis_manganese', 'soil_analysis_manganese_activity',
    'soil_analysis_boron', 'soil_analysis_copper', 'soil_analysis_zinc',
    'soil_analysis_molybdenum', 'soil_analysis_sodium', 'soil_analysis_nickel',
    'soil_analysis_cobalt',
]


class SoilAnalysisSerializer(serializers.ModelSerializer):
    land_id = serializers.IntegerField(source='land.land_id', read_only=True)

    class Meta:
        model = LandsSoilAnalysis
        exclude = ['land']


class LandSerializer(serializers.ModelSerializer):
    soil_analyses = SoilAnalysisSerializer(many=True, read_only=True)
    last_irrigation = serializers.SerializerMethodField()
    activity_count = serializers.SerializerMethodField()
    crops = serializers.SerializerMethodField()

    class Meta:
        model = Lands
        fields = [
            'land_id', 'land_name', 'land_slug', 'land_location', 'land_gps',
            'land_sketch', 'land_size', 'land_inclination', 'land_sun_exposure',
            'land_elevation', 'land_levels', 'land_water', 'land_notes', 'land_status',
            'current_farm', 'soil_analyses', 'created_at',
            'last_irrigation', 'activity_count', 'crops',
        ]

    def get_last_irrigation(self, obj):
        try:
            last = (
                WaterUsageLog.objects
                .filter(land_id=obj.land_id, deleted_at__isnull=True)
                .order_by('-water_usage_usage_date')
                .values_list('water_usage_usage_date', flat=True)
                .first()
            )
            return last.isoformat() if last else None
        except Exception:
            return None

    def get_activity_count(self, obj):
        try:
            from activities.models import Activities
            return Activities.objects.filter(
                land_id=obj.land_id,
                deleted_at__isnull=True,
            ).count()
        except Exception:
            return 0

    def get_crops(self, obj):
        try:
            from yields_app.models import Yields
            from crops.models import Crops
            yields = list(Yields.objects.filter(
                land_id=obj.land_id,
                deleted_at__isnull=True,
            ).values_list('crop_id', flat=True))
            if not yields:
                return []
            crop_rows = Crops.objects.filter(
                crop_id__in=yields,
            ).values('crop_id', 'crop_name')
            return [{'crop_id': c['crop_id'], 'crop_name': c['crop_name']} for c in crop_rows]
        except Exception:
            return []


class LandCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Lands
        fields = [
            'land_name', 'land_location', 'land_gps', 'land_sketch', 'land_size',
            'land_inclination', 'land_sun_exposure', 'land_elevation', 'land_levels',
            'land_water', 'land_notes', 'land_status', 'current_farm',
        ]

    def create(self, validated_data):
        request = self.context.get('request')
        user_id = request.user.user_id if request else 1
        name = validated_data['land_name']
        return Lands.objects.create(
            land_name=name,
            land_slug=slugify(name),
            created_at=timezone.now(),
            created_by=user_id,
            **{k: v for k, v in validated_data.items() if k != 'land_name'}
        )