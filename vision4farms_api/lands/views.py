import os
import uuid

from django.conf import settings
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.views import APIView
from farms.permissions import IsFarmMember, IsGestorOrReadOnly
from .models import Lands, LandsSoilAnalysis, WaterUsageLog, WaterIrrigationPlanned
from .serializers import (
    LandSerializer, LandCreateSerializer,
    SoilAnalysisSerializer, SOIL_NUTRIENT_FIELDS,
)
from .pdf_utils import soil_analysis_pdf


class LandListView(generics.ListAPIView):
    serializer_class = LandSerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        qs = Lands.objects.filter(land_status=1, deleted_at__isnull=True)
        farm_id = self.request.query_params.get('farm_id')
        if farm_id:
            qs = qs.filter(current_farm_id=farm_id)
        return qs


class LandDetailView(generics.RetrieveUpdateAPIView):
    queryset = Lands.objects.filter(land_status=1, deleted_at__isnull=True)
    serializer_class = LandSerializer
    lookup_field = 'land_id'

    def perform_update(self, serializer):
        request = self.request
        serializer.save(
            updated_at=timezone.now(),
            updated_by=request.user.user_id,
        )


class LandCreateView(generics.CreateAPIView):
    queryset = Lands.objects.all()
    serializer_class = LandCreateSerializer
    permission_classes = [IsGestorOrReadOnly]


class LandIrrigationView(APIView):
    """GET /lands/<land_id>/irrigation/ — histórico e planeamento de rega."""

    def get(self, request, land_id):
        usage = WaterUsageLog.objects.filter(
            land_id=land_id,
            deleted_at__isnull=True,
        ).order_by('-water_usage_usage_date').values(
            'water_usage_id', 'water_usage_usage_date',
            'water_usage_volume_liters', 'water_usage_cost',
            'water_usage_method', 'water_usage_purpose', 'water_usage_notes',
        )[:20]

        planned = WaterIrrigationPlanned.objects.filter(
            land_id=land_id,
            irrigation_status=0,
            deleted_at__isnull=True,
        ).order_by('planned_date').values(
            'planned_id', 'planned_date', 'planned_time',
            'planned_duration_min', 'planned_volume_liters',
            'irrigation_method', 'irrigation_status', 'planned_notes',
        )[:10]

        return Response({
            'usage': list(usage),
            'planned': list(planned),
        })


def _apply_nutrient_fields(analysis, data):
    for field in SOIL_NUTRIENT_FIELDS:
        if field in data:
            value = data.get(field)
            if value == '':
                value = None
            setattr(analysis, field, value)


class SoilAnalysisCreateView(APIView):
    """POST /lands/<land_id>/soil-analyses/ — criar análise de solo.

    Aceita JSON com todos os campos de nutrientes (opcionais) ou
    multipart com ficheiro PDF.
    """
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request, land_id):
        try:
            land = Lands.objects.get(land_id=land_id, deleted_at__isnull=True)
        except Lands.DoesNotExist:
            return Response(
                {'detail': 'Terreno não encontrado.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        date = request.data.get('soil_analysis_date')
        sample = request.data.get('soil_analysis_sample')
        if not date or not sample:
            return Response(
                {'detail': 'Data e amostra são obrigatórias.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        rel_path = ''
        pdf = request.FILES.get('file')
        if pdf:
            ext = os.path.splitext(pdf.name)[1] or '.pdf'
            filename = f'{uuid.uuid4().hex}{ext}'
            rel_path = os.path.join('soil_analyses', str(land_id), filename).replace('\\', '/')
            full_path = os.path.join(settings.MEDIA_ROOT, rel_path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'wb+') as f:
                for chunk in pdf.chunks():
                    f.write(chunk)

        analysis = LandsSoilAnalysis(
            land=land,
            soil_analysis_date=date,
            soil_analysis_sample=sample,
            soil_analysis_file=rel_path,
            created_at=timezone.now(),
            created_by=request.user.user_id,
        )
        _apply_nutrient_fields(analysis, request.data)
        analysis.save()

        return Response(
            SoilAnalysisSerializer(analysis).data,
            status=status.HTTP_201_CREATED,
        )


class SoilAnalysisListView(generics.ListAPIView):
    serializer_class = SoilAnalysisSerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        land_id = self.kwargs.get('land_id')
        return LandsSoilAnalysis.objects.filter(
            land_id=land_id,
            deleted_at__isnull=True,
        ).order_by('-soil_analysis_date')


class SoilAnalysisDetailView(APIView):
    """GET/PATCH/DELETE /lands/soil-analyses/<id>/"""
    permission_classes = [IsFarmMember]

    def _get(self, analysis_id):
        try:
            return LandsSoilAnalysis.objects.get(
                soil_analysis_id=analysis_id, deleted_at__isnull=True,
            )
        except LandsSoilAnalysis.DoesNotExist:
            return None

    def get(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(SoilAnalysisSerializer(a).data)

    def patch(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if 'soil_analysis_date' in request.data:
            a.soil_analysis_date = request.data['soil_analysis_date']
        if 'soil_analysis_sample' in request.data:
            a.soil_analysis_sample = request.data['soil_analysis_sample']
        _apply_nutrient_fields(a, request.data)
        a.updated_at = timezone.now()
        a.updated_by = request.user.user_id
        a.save()
        return Response(SoilAnalysisSerializer(a).data)

    def delete(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        a.deleted_at = timezone.now()
        a.deleted_by = request.user.user_id
        a.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class SoilAnalysisPDFView(APIView):
    """GET /lands/soil-analyses/<id>/pdf/ — gera PDF com os valores da análise."""
    permission_classes = [IsFarmMember]

    def get(self, request, analysis_id):
        try:
            a = LandsSoilAnalysis.objects.get(
                soil_analysis_id=analysis_id, deleted_at__isnull=True,
            )
        except LandsSoilAnalysis.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        land_name = ''
        try:
            land_name = a.land.land_name
        except Exception:
            pass

        try:
            data = soil_analysis_pdf(a, land_name=land_name)
        except Exception as e:
            import logging, traceback
            logging.error(
                '[SoilAnalysisPDF] erro a gerar PDF id=%s: %s\n%s',
                analysis_id, e, traceback.format_exc(),
            )
            return Response(
                {'detail': f'Erro a gerar PDF: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        response = HttpResponse(data, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'inline; filename="analise_solo_{a.soil_analysis_id}.pdf"'
        )
        return response
