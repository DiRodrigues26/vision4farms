from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from farms.models import Farms, ProfilesHasFarms
from lands.models import Lands
from activities.models import Activities


class MapDataView(APIView):
    """
    GET /api/map/<farm_id>/
    Retorna todos os terrenos da exploração com:
      - dados completos (incluindo land_sketch para GeoJSON)
      - contagem de atividades pendentes e atrasadas por terreno
      - cultura ativa principal por terreno (se existir)
    Otimizado para o ecrã do mapa — um único pedido.
    """

    def get(self, request, farm_id):
        # Verificar acesso
        try:
            profile = request.user.profile
            phf = ProfilesHasFarms.objects.filter(
                profile_id=profile.profile_id,
                farm_id=farm_id,
                connection_status=1,
                deleted_at__isnull=True,
            ).first()
            if not phf:
                return Response(
                    {'detail': 'Sem acesso a esta exploração.'},
                    status=status.HTTP_403_FORBIDDEN
                )
            farm = Farms.objects.get(farm_id=farm_id)
        except Exception:
            return Response(
                {'detail': 'Exploração não encontrada.'},
                status=status.HTTP_404_NOT_FOUND
            )

        today = timezone.now().date()

        # Terrenos da exploração
        lands = Lands.objects.filter(
            current_farm_id=farm_id,
            land_status=1,
            deleted_at__isnull=True
        )

        # Atividades pendentes e atrasadas (uma query cada)
        land_ids = list(lands.values_list('land_id', flat=True))

        pending_qs = (
            Activities.objects
            .filter(
                farm_id=farm_id,
                land_id__in=land_ids,
                activity_status=0,
                activity_date_planned__gte=today,
                deleted_at__isnull=True,
            )
            .values('land_id')
        )
        overdue_qs = (
            Activities.objects
            .filter(
                farm_id=farm_id,
                land_id__in=land_ids,
                activity_status=0,
                activity_date_planned__lt=today,
                deleted_at__isnull=True,
            )
            .values('land_id')
        )

        # Contagens por terreno
        pending_counts: dict[int, int] = {}
        for row in pending_qs:
            lid = row['land_id']
            pending_counts[lid] = pending_counts.get(lid, 0) + 1

        overdue_counts: dict[int, int] = {}
        for row in overdue_qs:
            lid = row['land_id']
            overdue_counts[lid] = overdue_counts.get(lid, 0) + 1

        # Tipos de atividade pendente por terreno
        type_qs = (
            Activities.objects
            .filter(
                farm_id=farm_id,
                land_id__in=land_ids,
                activity_status=0,
                deleted_at__isnull=True,
            )
            .values('land_id', 'activity_type')
        )
        types_by_land: dict[int, set] = {}
        for row in type_qs:
            lid = row['land_id']
            types_by_land.setdefault(lid, set()).add(row['activity_type'])

        # Atividades concluídas por terreno
        done_qs = (
            Activities.objects
            .filter(
                farm_id=farm_id,
                land_id__in=land_ids,
                activity_status=1,
                deleted_at__isnull=True,
            )
            .values('land_id')
        )
        done_counts: dict[int, int] = {}
        for row in done_qs:
            lid = row['land_id']
            done_counts[lid] = done_counts.get(lid, 0) + 1

        # Cultura ativa por terreno (opcional)
        crop_by_land: dict[int, str] = {}
        try:
            from activities.models import Yields
            yields = Yields.objects.filter(
                farm_id=farm_id,
                yield_status=1,
                deleted_at__isnull=True,
            ).values('land_id', 'yield_name')
            for y in yields:
                lid = y['land_id']
                if lid not in crop_by_land:
                    crop_by_land[lid] = y['yield_name']
        except Exception:
            pass

        # Montar resposta
        lands_data = []
        for land in lands:
            lid = land.land_id
            lands_data.append({
                'land_id':         lid,
                'land_name':       land.land_name,
                'land_slug':       land.land_slug,
                'land_location':   land.land_location,
                'land_gps':        land.land_gps,
                'land_sketch':     land.land_sketch,   # GeoJSON
                'land_size':       float(land.land_size) if land.land_size else None,
                'land_inclination':land.land_inclination,
                'land_sun_exposure':land.land_sun_exposure,
                'land_elevation':  land.land_elevation,
                'land_water':      land.land_water,
                'land_notes':      land.land_notes,
                # Atividades
                'pending_activities': pending_counts.get(lid, 0),
                'overdue_activities': overdue_counts.get(lid, 0),
                'done_activities':   done_counts.get(lid, 0),
                'activity_types':    list(types_by_land.get(lid, [])),
                # Cultura
                'crop_name':       crop_by_land.get(lid),
            })

        return Response({
            'farm': {
                'farm_id':      farm.farm_id,
                'farm_name':    farm.farm_name,
                'farm_gps':     farm.farm_gps,
                'farm_city':    farm.farm_city,
                'farm_district':farm.farm_district,
            },
            'lands': lands_data,
            'total_lands':    len(lands_data),
            'total_area_ha':  round(
                sum(l['land_size'] or 0 for l in lands_data), 3
            ),
        })
