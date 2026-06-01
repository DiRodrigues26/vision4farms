from rest_framework import serializers
from .models import Crops, CropsVarieties


class VarietySerializer(serializers.ModelSerializer):
    class Meta:
        model = CropsVarieties
        fields = ['variety_id', 'variety_name', 'variety_description',
                  'strong_points', 'weak_points', 'variety_observations']


class CropSerializer(serializers.ModelSerializer):
    varieties = VarietySerializer(many=True, read_only=True)

    class Meta:
        model = Crops
        fields = [
            'crop_id', 'crop_name', 'crop_type', 'production_cycle',
            'planting_season', 'harvest_season', 'preferred_climate',
            'preferred_soil', 'water_needs', 'common_enemies',
            'crop_observations', 'varieties',
        ]
