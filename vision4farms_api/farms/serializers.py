from django.utils import timezone
from django.utils.text import slugify
from rest_framework import serializers
from .models import Farms, Companies


class CompanySerializer(serializers.ModelSerializer):
    class Meta:
        model = Companies
        fields = ['company_id', 'company_name', 'company_email', 'company_city', 'company_district']


class CompanyCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Companies
        fields = [
            'company_name', 'company_email', 'company_nif', 'company_nifap',
            'company_address', 'company_zipcode', 'company_city',
            'company_district', 'company_country', 'company_mobile', 'company_phone',
        ]
        extra_kwargs = {
            'company_nif': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_nifap': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_address': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_zipcode': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_city': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_district': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_country': {'required': False, 'allow_null': True, 'allow_blank': True},
            'company_mobile': {'required': False, 'allow_null': True},
            'company_phone': {'required': False, 'allow_null': True},
        }

    def create(self, validated_data):
        name = validated_data['company_name']
        created_by = validated_data.pop('created_by', 1)
        return Companies.objects.create(
            company_name=name,
            company_slug=slugify(name),
            company_email=validated_data['company_email'],
            company_nif=validated_data.get('company_nif'),
            company_nifap=validated_data.get('company_nifap'),
            company_address=validated_data.get('company_address'),
            company_zipcode=validated_data.get('company_zipcode'),
            company_city=validated_data.get('company_city'),
            company_district=validated_data.get('company_district'),
            company_country=validated_data.get('company_country', 'Portugal'),
            company_mobile=validated_data.get('company_mobile'),
            company_phone=validated_data.get('company_phone'),
            company_status=1,
            created_by=created_by,
        )


class FarmSerializer(serializers.ModelSerializer):
    company = CompanySerializer(source='current_company', read_only=True)

    class Meta:
        model = Farms
        fields = [
            'farm_id', 'farm_name', 'farm_slug', 'farm_address',
            'farm_zipcode', 'farm_location', 'farm_city', 'farm_district',
            'farm_country', 'farm_gps', 'farm_description', 'farm_status',
            'company', 'created_at',
        ]


class FarmCreateSerializer(serializers.ModelSerializer):
    current_company = serializers.PrimaryKeyRelatedField(
        queryset=Companies.objects.all()
    )

    class Meta:
        model = Farms
        fields = [
            'farm_name', 'farm_address', 'farm_zipcode', 'farm_location',
            'farm_city', 'farm_district', 'farm_country', 'farm_gps',
            'farm_description', 'farm_status', 'current_company',
        ]

    def create(self, validated_data):
        name = validated_data['farm_name']
        created_by = validated_data.pop('created_by', 1)
        return Farms.objects.create(
            farm_name=name,
            farm_slug=slugify(name),
            farm_address=validated_data.get('farm_address'),
            farm_zipcode=validated_data.get('farm_zipcode'),
            farm_location=validated_data.get('farm_location'),
            farm_city=validated_data.get('farm_city'),
            farm_district=validated_data.get('farm_district'),
            farm_country=validated_data.get('farm_country'),
            farm_gps=validated_data.get('farm_gps'),
            farm_description=validated_data.get('farm_description'),
            farm_status=validated_data.get('farm_status', 1),
            created_at=timezone.now(),
            created_by=created_by,
            current_company=validated_data['current_company'],
        )