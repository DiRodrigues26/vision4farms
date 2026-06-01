from rest_framework import generics
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Crops, CropsVarieties
from .serializers import CropSerializer
from yields_app.models import Yields
from activities.models import Activities, Observations
from lands.models import Lands, WaterUsageLog, WaterIrrigationPlanned


class CropListView(generics.ListAPIView):
    queryset = Crops.objects.filter(deleted_at__isnull=True)
    serializer_class = CropSerializer


class CropDetailView(generics.RetrieveAPIView):
    queryset = Crops.objects.filter(deleted_at__isnull=True)
    serializer_class = CropSerializer
    lookup_field = 'crop_id'


class CropFarmListView(APIView):
    """GET /crops/farm/<farm_id>/ — culturas presentes na farm, agrupadas por crop."""

    def get(self, request, farm_id):
        # Yields activos nesta farm
        qs = Yields.objects.filter(
            farm_id=farm_id, yield_status=1, deleted_at__isnull=True,
        )

        # Agrupar por crop_id
        crop_ids = list(qs.values_list('crop_id', flat=True).distinct())

        results = []
        for crop_id in crop_ids:
            crop = Crops.objects.filter(
                crop_id=crop_id, deleted_at__isnull=True,
            ).first()
            if not crop:
                continue

            yields_for_crop = qs.filter(crop_id=crop_id)
            yield_ids = list(yields_for_crop.values_list('yield_id', flat=True))

            # Terrenos
            lands = []
            total_area = 0
            for y in yields_for_crop:
                land = Lands.objects.filter(
                    land_id=y.land_id, deleted_at__isnull=True,
                ).first()
                size = float(y.yield_size) if y.yield_size else 0
                total_area += size
                lands.append({
                    'land_id': y.land_id,
                    'land_name': land.land_name if land else None,
                    'yield_size': size,
                })

            # Contagem de atividades
            activity_count = Activities.objects.filter(
                yield_id__in=yield_ids, deleted_at__isnull=True,
            ).count()

            # Última rega (atividade do tipo irrigation)
            last_irr = (
                Activities.objects
                .filter(
                    yield_id__in=yield_ids,
                    activity_type='irrigation',
                    deleted_at__isnull=True,
                )
                .order_by('-activity_date_done', '-activity_date_planned')
                .values_list('activity_date_done', 'activity_date_planned')
                .first()
            )
            last_irrigation = None
            if last_irr:
                last_irrigation = last_irr[0] or last_irr[1]

            # Observações count
            obs_count = Observations.objects.filter(
                yield_id__in=yield_ids, deleted_at__isnull=True,
            ).count()

            results.append({
                'crop_id': crop.crop_id,
                'crop_name': crop.crop_name,
                'crop_type': crop.crop_type,
                'production_cycle': crop.production_cycle,
                'lands': lands,
                'total_area_ha': total_area,
                'activity_count': activity_count,
                'observation_count': obs_count,
                'last_irrigation': last_irrigation,
                'yield_count': len(yield_ids),
            })

        return Response(results)


class CropHubView(APIView):
    """GET /crops/<crop_id>/hub/?farm_id=X — dados agregados da cultura."""

    def get(self, request, crop_id):
        from yields_app.models import YieldsHarvests, YieldsAnalysis

        farm_id = request.query_params.get('farm_id')

        # Crop info
        try:
            crop = Crops.objects.get(crop_id=crop_id, deleted_at__isnull=True)
        except Crops.DoesNotExist:
            return Response({'detail': 'Cultura não encontrada.'}, status=404)

        varieties = CropsVarieties.objects.filter(
            crop_id=crop_id, deleted_at__isnull=True,
        ).values('variety_id', 'variety_name', 'variety_description',
                 'strong_points', 'weak_points')

        # Yields desta cultura nesta farm
        qs_yields = Yields.objects.filter(
            crop_id=crop_id, yield_status=1, deleted_at__isnull=True,
        )
        if farm_id:
            qs_yields = qs_yields.filter(farm_id=farm_id)

        yield_ids = list(qs_yields.values_list('yield_id', flat=True))

        # Terrenos (yields + land info)
        yields_data = []
        for y in qs_yields:
            land = Lands.objects.filter(
                land_id=y.land_id, deleted_at__isnull=True,
            ).first()
            yields_data.append({
                'yield_id': y.yield_id,
                'yield_name': y.yield_name,
                'yield_method': y.yield_method,
                'yield_size': float(y.yield_size) if y.yield_size else 0,
                'yield_estimated': y.yield_estimated,
                'yield_unit': y.yield_unit,
                'yield_notes': y.yield_notes,
                'land_id': y.land_id,
                'land_name': land.land_name if land else None,
                'land_size': float(land.land_size) if land and land.land_size else None,
                'variety_id': y.variety_id,
            })

        # Atividades de todos os yields
        activities = Activities.objects.filter(
            yield_id__in=yield_ids, deleted_at__isnull=True,
        ).order_by('-activity_date_planned').values(
            'activity_id', 'activity_name', 'activity_type',
            'activity_status', 'activity_priority',
            'activity_date_planned', 'activity_date_done',
            'land_id', 'yield_id',
        )[:30]

        # Observações de todos os yields
        observations = Observations.objects.filter(
            yield_id__in=yield_ids, deleted_at__isnull=True,
        ).order_by('-created_at').values(
            'observation_id', 'observation_text', 'praga_fungo',
            'estado_fenologico', 'land_id', 'yield_id', 'created_at',
        )[:20]

        # Colheitas
        harvests = YieldsHarvests.objects.filter(
            yield_field_id__in=yield_ids, deleted_at__isnull=True,
        ).order_by('-harvest_date').values(
            'harvest_id', 'harvest_date', 'harvest_name',
            'harvest_harvested', 'unit_measurement',
            'total_harvest_cost', 'yield_field_id',
        )[:20]

        # Análises foliares
        analyses = YieldsAnalysis.objects.filter(
            yield_field_id__in=yield_ids, deleted_at__isnull=True,
        ).order_by('-yield_analysis_date').values(
            'yield_analysis_id', 'yield_analysis_date', 'yield_analysis_sample',
            'yield_analysis_nitrogen_total', 'yield_analysis_phosphorus',
            'yield_analysis_potassium', 'yield_analysis_calcium',
            'yield_analysis_magnesium', 'yield_analysis_iron',
            'yield_analysis_manganese', 'yield_analysis_boro',
            'yield_analysis_zinc', 'yield_analysis_file', 'yield_field_id',
        )[:20]

        # Rega — recolher dados de irrigação dos terrenos associados
        land_ids = list(qs_yields.values_list('land_id', flat=True).distinct())

        irrigation_usage = WaterUsageLog.objects.filter(
            land_id__in=land_ids,
            deleted_at__isnull=True,
        ).order_by('-water_usage_usage_date').values(
            'water_usage_id', 'water_usage_usage_date',
            'water_usage_volume_liters', 'water_usage_cost',
            'water_usage_method', 'water_usage_purpose', 'water_usage_notes',
            'land_id',
        )[:30]

        irrigation_planned = WaterIrrigationPlanned.objects.filter(
            land_id__in=land_ids,
            irrigation_status=0,
            deleted_at__isnull=True,
        ).order_by('planned_date').values(
            'planned_id', 'planned_date', 'planned_time',
            'planned_duration_min', 'planned_volume_liters',
            'irrigation_method', 'irrigation_status', 'planned_notes',
            'land_id',
        )[:15]

        return Response({
            'crop': {
                'crop_id': crop.crop_id,
                'crop_name': crop.crop_name,
                'crop_type': crop.crop_type,
                'production_cycle': crop.production_cycle,
                'planting_season': crop.planting_season,
                'harvest_season': crop.harvest_season,
                'preferred_climate': crop.preferred_climate,
                'preferred_soil': crop.preferred_soil,
                'water_needs': crop.water_needs,
                'common_enemies': crop.common_enemies,
                'crop_observations': crop.crop_observations,
                'varieties': list(varieties),
            },
            'yields': yields_data,
            'activities': list(activities),
            'observations': list(observations),
            'harvests': list(harvests),
            'analyses': list(analyses),
            'irrigation': {
                'usage': list(irrigation_usage),
                'planned': list(irrigation_planned),
            },
        })
