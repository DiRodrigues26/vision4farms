from django.db.models import Q
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from farms.models import Farms, ProfilesHasFarms
from lands.models import Lands, LandsSoilAnalysis
from activities.models import Activities, Observations
from agenda.models import Agenda
from notifications_app.models import Notifications


class DashboardView(APIView):

    def get(self, request, farm_id):
        try:
            profile = request.user.profile
            phf = ProfilesHasFarms.objects.filter(
                profile_id=profile.profile_id,
                farm_id=farm_id,
                connection_status=1,
                deleted_at__isnull=True,
            ).first()

            if not phf:
                return Response({'detail': 'Sem acesso a esta exploração.'}, status=status.HTTP_403_FORBIDDEN)

            farm = Farms.objects.get(farm_id=farm_id)
            user_role = phf.connection_role  # 1=Gestor, 2=Colaborador, 3=Consultor

        except Exception:
            return Response({'detail': 'Exploração não encontrada.'}, status=status.HTTP_404_NOT_FOUND)

        today = timezone.now().date()

        # ── Terrenos ───────────────────────────────────────
        lands = Lands.objects.filter(
            current_farm_id=farm_id,
            land_status=1,
            deleted_at__isnull=True
        )
        total_lands = lands.count()
        total_area_ha = sum(float(l.land_size) for l in lands if l.land_size)

        # ── Atividades ─────────────────────────────────────
        activities_qs = Activities.objects.filter(
            farm_id=farm_id,
            deleted_at__isnull=True
        )
        pending = activities_qs.filter(activity_status=0).count()
        overdue = activities_qs.filter(
            activity_status=0,
            activity_date_planned__lt=today
        ).count()
        urgent = activities_qs.filter(
            activity_status=0,
            activity_priority=3
        ).count()
        done_this_month = activities_qs.filter(
            activity_status=1,
            activity_date_done__month=today.month,
            activity_date_done__year=today.year,
        ).count()

        # Próximas 5 atividades com detalhe
        next_activities = []
        for a in activities_qs.filter(
            activity_status=0,
            activity_date_planned__gte=today
        ).order_by('activity_date_planned')[:5]:
            land_name = ''
            try:
                land = Lands.objects.get(land_id=a.land_id)
                land_name = land.land_name
            except Exception:
                pass
            next_activities.append({
                'activity_id': a.activity_id,
                'activity_name': a.activity_name,
                'activity_type': a.activity_type,
                'activity_date_planned': a.activity_date_planned,
                'activity_priority': a.activity_priority,
                'land_id': a.land_id,
                'land_name': land_name,
            })

        # ── Agenda ─────────────────────────────────────────
        agenda_qs = Agenda.objects.filter(
            farm_id=farm_id,
            deleted_at__isnull=True,
        )
        agenda_pending = agenda_qs.filter(agenda_status=0).count()
        agenda_this_month = agenda_qs.filter(
            agenda_date__month=today.month,
            agenda_date__year=today.year,
        ).count()

        # ── Rega ───────────────────────────────────────────
        last_irrigation = None
        next_irrigations = []
        try:
            from lands.models import WaterUsageLog, WaterIrrigationPlanned
            last_log = WaterUsageLog.objects.filter(
                land_id__in=lands.values_list('land_id', flat=True),
                deleted_at__isnull=True,
            ).order_by('-water_usage_usage_date').first()

            if last_log:
                last_irrigation = {
                    'date': last_log.water_usage_usage_date,
                    'volume_liters': float(last_log.water_usage_volume_liters) if last_log.water_usage_volume_liters else None,
                }

            planned = WaterIrrigationPlanned.objects.filter(
                farm_id=farm_id,
                irrigation_status=0,
                planned_date__gte=today,
                deleted_at__isnull=True,
            ).order_by('planned_date')[:3]

            for p in planned:
                land_name = ''
                try:
                    land = Lands.objects.get(land_id=p.land_id)
                    land_name = land.land_name
                except Exception:
                    pass
                next_irrigations.append({
                    'planned_id': p.planned_id,
                    'planned_date': p.planned_date,
                    'planned_volume_liters': float(p.planned_volume_liters) if p.planned_volume_liters else None,
                    'land_id': p.land_id,
                    'land_name': land_name,
                })
        except Exception:
            pass

        # ── Culturas ativas ────────────────────────────────
        active_yields = []
        try:
            from activities.models import Yields
            from lands.models import WaterUsageLog, WaterIrrigationPlanned
            yields_qs = Yields.objects.filter(
                farm_id=farm_id,
                yield_status=1,
                deleted_at__isnull=True,
            )[:5]
            for y in yields_qs:
                land_name = ''
                try:
                    land = Lands.objects.get(land_id=y.land_id)
                    land_name = land.land_name
                except Exception:
                    pass

                # Última rega: usage log no mesmo land (não há yield_id no log)
                y_last = WaterUsageLog.objects.filter(
                    land_id=y.land_id,
                    deleted_at__isnull=True,
                ).order_by('-water_usage_usage_date').first()
                last_irr = y_last.water_usage_usage_date.isoformat() if y_last else None

                # Próxima rega: planeada com yield_id se existir, senão por land
                y_next_qs = WaterIrrigationPlanned.objects.filter(
                    irrigation_status=0,
                    planned_date__gte=today,
                    deleted_at__isnull=True,
                ).filter(
                    Q(yield_id=y.yield_id) | Q(land_id=y.land_id, yield_id__isnull=True)
                ).order_by('planned_date', 'planned_time')
                y_next = y_next_qs.first()
                if y_next:
                    if y_next.planned_time:
                        next_irr = f"{y_next.planned_date.isoformat()}T{y_next.planned_time.isoformat()}"
                    else:
                        next_irr = y_next.planned_date.isoformat()
                else:
                    next_irr = None

                active_yields.append({
                    'yield_id': y.yield_id,
                    'yield_name': y.yield_name,
                    'yield_size': float(y.yield_size) if y.yield_size else None,
                    'land_id': y.land_id,
                    'land_name': land_name,
                    'last_irrigation': last_irr,
                    'next_irrigation': next_irr,
                })
        except Exception:
            pass

        # ── Análises recentes (solo + foliar) ─────────────
        land_ids = list(lands.values_list('land_id', flat=True))

        recent_soil = list(
            LandsSoilAnalysis.objects.filter(
                land_id__in=land_ids,
                deleted_at__isnull=True,
            ).order_by('-soil_analysis_date').values(
                'soil_analysis_id', 'soil_analysis_date',
                'soil_analysis_sample', 'land_id',
            )[:5]
        )

        from yields_app.models import Yields as YieldsModel, YieldsAnalysis
        yield_ids = list(YieldsModel.objects.filter(
            farm_id=farm_id, yield_status=1, deleted_at__isnull=True,
        ).values_list('yield_id', flat=True))
        recent_foliar = list(
            YieldsAnalysis.objects.filter(
                yield_field_id__in=yield_ids,
                deleted_at__isnull=True,
            ).order_by('-yield_analysis_date').values(
                'yield_analysis_id', 'yield_analysis_date',
                'yield_analysis_sample', 'yield_field_id',
            )[:5]
        )

        # ── Observações recentes ───────────────────────────
        recent_observations = list(
            Observations.objects.filter(
                farm_id=farm_id,
                deleted_at__isnull=True
            ).order_by('-created_at').values(
                'observation_id', 'observation_text', 'praga_fungo',
                'land_id', 'created_at'
            )[:3]
        )

        # ── Notificações ───────────────────────────────────
        unread_notifications = Notifications.objects.filter(
            user=request.user,
            notification_read=0,
            deleted_at__isnull=True
        ).count()

        return Response({
            'farm': {
                'farm_id': farm.farm_id,
                'farm_name': farm.farm_name,
                'farm_city': farm.farm_city,
                'farm_district': farm.farm_district,
                'farm_gps': farm.farm_gps,
            },
            'user_role': user_role,
            'summary': {
                'total_lands': total_lands,
                'total_area_ha': round(total_area_ha, 3),
                'unread_notifications': unread_notifications,
            },
            'activities': {
                'pending': pending,
                'overdue': overdue,
                'urgent': urgent,
                'done_this_month': done_this_month,
                'next': next_activities,
            },
            'irrigation': {
                'last': last_irrigation,
                'next': next_irrigations,
            },
            'agenda': {
                'pending': agenda_pending,
                'this_month': agenda_this_month,
            },
            'active_yields': active_yields,
            'recent_observations': recent_observations,
            'analyses': {
                'soil': recent_soil,
                'foliar': recent_foliar,
            },
        })


class DashboardFarmsView(APIView):

    def get(self, request):
        try:
            profile = request.user.profile
            phf_list = ProfilesHasFarms.objects.filter(
                profile_id=profile.profile_id,
                connection_status=1,
                deleted_at__isnull=True,
            )

            result = []
            for phf in phf_list:
                try:
                    farm = Farms.objects.get(
                        farm_id=phf.farm_id,
                        farm_status=1,
                        deleted_at__isnull=True
                    )
                    # Calcular área total dos terrenos da exploração
                    lands_qs = Lands.objects.filter(
                        current_farm_id=farm.farm_id,
                        land_status=1,
                        deleted_at__isnull=True
                    )
                    total_area = sum(
                        float(l.land_size) for l in lands_qs if l.land_size
                    )
                    result.append({
                        'farm_id': farm.farm_id,
                        'farm_name': farm.farm_name,
                        'farm_city': farm.farm_city,
                        'farm_district': farm.farm_district,
                        'farm_gps': farm.farm_gps,
                        'farm_description': farm.farm_description,
                        'farm_size': round(total_area, 3),
                        'user_role': phf.connection_role,
                    })
                except Farms.DoesNotExist:
                    continue

            return Response(result)
        except Exception as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)