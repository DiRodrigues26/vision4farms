from django.utils import timezone
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from farms.permissions import IsFarmMember, IsGestorOrReadOnly
from .models import (
    WaterSource,
    WaterSourceType,
    WaterIrrigationMethod,
    WaterUsageLog,
    WaterIrrigationPlanned,
)
from .water_serializers import (
    WaterSourceTypeSerializer,
    WaterIrrigationMethodSerializer,
    WaterSourceSerializer,
    WaterSourceWriteSerializer,
    WaterUsageLogSerializer,
    WaterUsageLogWriteSerializer,
    WaterIrrigationPlannedSerializer,
    WaterIrrigationPlannedWriteSerializer,
)


# ══════════════════════════════════════════════════════════════
# Lookups (tipos de fonte e métodos de rega)
# ══════════════════════════════════════════════════════════════

class WaterSourceTypeListView(generics.ListAPIView):
    """GET /water/types/ — lista de tipos de fonte de água."""
    queryset = WaterSourceType.objects.all().order_by('water_type_name')
    serializer_class = WaterSourceTypeSerializer
    permission_classes = [IsAuthenticated]


class WaterIrrigationMethodListView(generics.ListAPIView):
    """GET /water/methods/ — lista de métodos de rega."""
    queryset = WaterIrrigationMethod.objects.all().order_by('water_irrigation_name')
    serializer_class = WaterIrrigationMethodSerializer
    permission_classes = [IsAuthenticated]


# ══════════════════════════════════════════════════════════════
# Water Source — CRUD
# ══════════════════════════════════════════════════════════════

class WaterSourceListCreateView(generics.ListCreateAPIView):
    """GET/POST /water/sources/?farm_id=<id>"""
    permission_classes = [IsGestorOrReadOnly]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return WaterSourceWriteSerializer
        return WaterSourceSerializer

    def get_queryset(self):
        qs = WaterSource.objects.filter(deleted_at__isnull=True).order_by('water_source_name')
        farm_id = self.request.query_params.get('farm_id')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        return qs

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(
            WaterSourceSerializer(instance).data,
            status=status.HTTP_201_CREATED,
        )


class WaterSourceDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /water/sources/<id>/"""
    queryset = WaterSource.objects.filter(deleted_at__isnull=True)
    lookup_field = 'water_source_id'
    permission_classes = [IsGestorOrReadOnly]

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return WaterSourceWriteSerializer
        return WaterSourceSerializer

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(WaterSourceSerializer(instance).data)

    def perform_destroy(self, instance):
        instance.deleted_at = timezone.now()
        instance.deleted_by = self.request.user.user_id
        instance.save()


# ══════════════════════════════════════════════════════════════
# Water Usage Log — CRUD
# ══════════════════════════════════════════════════════════════

class WaterUsageLogListCreateView(generics.ListCreateAPIView):
    """GET/POST /water/usage-logs/?water_source_id=<id>&land_id=<id>&farm_id=<id>"""
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return WaterUsageLogWriteSerializer
        return WaterUsageLogSerializer

    def get_queryset(self):
        qs = WaterUsageLog.objects.filter(deleted_at__isnull=True).order_by('-water_usage_usage_date')
        source_id = self.request.query_params.get('water_source_id')
        if source_id:
            qs = qs.filter(water_source_id=source_id)
        land_id = self.request.query_params.get('land_id')
        if land_id:
            qs = qs.filter(land_id=land_id)
        farm_id = self.request.query_params.get('farm_id')
        if farm_id:
            source_ids = WaterSource.objects.filter(
                farm_id=farm_id, deleted_at__isnull=True
            ).values_list('water_source_id', flat=True)
            qs = qs.filter(water_source_id__in=list(source_ids))
        return qs

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(
            WaterUsageLogSerializer(instance).data,
            status=status.HTTP_201_CREATED,
        )


class WaterUsageLogDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /water/usage-logs/<id>/"""
    queryset = WaterUsageLog.objects.filter(deleted_at__isnull=True)
    lookup_field = 'water_usage_id'
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return WaterUsageLogWriteSerializer
        return WaterUsageLogSerializer

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(WaterUsageLogSerializer(instance).data)

    def perform_destroy(self, instance):
        instance.deleted_at = timezone.now()
        instance.deleted_by = self.request.user.user_id
        instance.save()


# ══════════════════════════════════════════════════════════════
# Water Irrigation Planned — CRUD + Execute
# ══════════════════════════════════════════════════════════════

class WaterIrrigationPlannedListCreateView(generics.ListCreateAPIView):
    """GET/POST /water/planned/?farm_id=<id>&land_id=<id>&water_source_id=<id>&status=<0|1|2>"""
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return WaterIrrigationPlannedWriteSerializer
        return WaterIrrigationPlannedSerializer

    def get_queryset(self):
        qs = WaterIrrigationPlanned.objects.filter(deleted_at__isnull=True).order_by('planned_date', 'planned_time')
        farm_id = self.request.query_params.get('farm_id')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        land_id = self.request.query_params.get('land_id')
        if land_id:
            qs = qs.filter(land_id=land_id)
        source_id = self.request.query_params.get('water_source_id')
        if source_id:
            qs = qs.filter(water_source_id=source_id)
        status_param = self.request.query_params.get('status')
        if status_param is not None and status_param != '':
            qs = qs.filter(irrigation_status=int(status_param))
        return qs

    def create(self, request, *args, **kwargs):
        write = self.get_serializer(data=request.data)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(
            WaterIrrigationPlannedSerializer(instance).data,
            status=status.HTTP_201_CREATED,
        )


class WaterIrrigationPlannedDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /water/planned/<id>/"""
    queryset = WaterIrrigationPlanned.objects.filter(deleted_at__isnull=True)
    lookup_field = 'planned_id'
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return WaterIrrigationPlannedWriteSerializer
        return WaterIrrigationPlannedSerializer

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        write = self.get_serializer(instance, data=request.data, partial=partial)
        write.is_valid(raise_exception=True)
        instance = write.save()
        return Response(WaterIrrigationPlannedSerializer(instance).data)

    def perform_destroy(self, instance):
        instance.deleted_at = timezone.now()
        instance.deleted_by = self.request.user.user_id
        instance.save()


class WaterIrrigationPlannedExecuteView(APIView):
    """POST /water/planned/<id>/execute/ — marca como executada e cria um usage_log.

    Body (opcional): volume_liters, cost, purpose, notes
    Se não fornecido, usa planned_volume_liters.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, planned_id):
        try:
            planned = WaterIrrigationPlanned.objects.get(
                planned_id=planned_id, deleted_at__isnull=True
            )
        except WaterIrrigationPlanned.DoesNotExist:
            return Response({'detail': 'Rega planeada não encontrada.'},
                            status=status.HTTP_404_NOT_FOUND)

        if planned.irrigation_status == 1:
            return Response({'detail': 'Já foi executada.'},
                            status=status.HTTP_400_BAD_REQUEST)
        if not planned.water_source_id:
            return Response({'detail': 'Rega planeada sem fonte de água definida.'},
                            status=status.HTTP_400_BAD_REQUEST)

        volume = request.data.get('volume_liters') or planned.planned_volume_liters
        if volume is None:
            return Response({'detail': 'Volume obrigatório.'},
                            status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        usage = WaterUsageLog.objects.create(
            water_source_id=planned.water_source_id,
            land_id=planned.land_id,
            water_usage_usage_date=now.date(),
            water_usage_volume_liters=volume,
            water_usage_cost=request.data.get('cost'),
            water_usage_method=planned.irrigation_method,
            water_usage_purpose=request.data.get('purpose') or 'Rega planeada executada',
            water_usage_notes=request.data.get('notes'),
            created_at=now,
            created_by=request.user.user_id,
        )

        planned.irrigation_status = 1
        planned.executed_at = now
        planned.water_usage_id = usage.water_usage_id
        planned.updated_at = now
        planned.updated_by = request.user.user_id
        planned.save()

        return Response({
            'planned': WaterIrrigationPlannedSerializer(planned).data,
            'usage': WaterUsageLogSerializer(usage).data,
        }, status=status.HTTP_200_OK)
