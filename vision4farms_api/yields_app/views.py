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
from .models import Yields, YieldsAnalysis, YieldsHarvests
from .serializers import (
    YieldListSerializer, YieldDetailSerializer, YieldCreateSerializer,
    YieldAnalysisSerializer, HarvestSerializer,
    YIELD_NUTRIENT_FIELDS, HARVEST_FIELDS,
)
from farms.models import ProfilesHasFarms
from lands.pdf_utils import foliar_analysis_pdf, harvest_pdf


def _allowed_farm_ids(request):
    try:
        profile_id = request.user.profile.profile_id
    except Exception:
        return []
    return list(
        ProfilesHasFarms.objects.filter(
            profile_id=profile_id,
            connection_status=1,
            deleted_at__isnull=True,
        ).values_list('farm_id', flat=True)
    )


class YieldListView(generics.ListAPIView):
    serializer_class = YieldListSerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        allowed = _allowed_farm_ids(self.request)
        qs = Yields.objects.filter(
            yield_status=1,
            deleted_at__isnull=True,
            farm_id__in=allowed,
        )
        farm_id = self.request.query_params.get('farm_id')
        land_id = self.request.query_params.get('land_id')
        crop_id = self.request.query_params.get('crop_id')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        if land_id:
            qs = qs.filter(land_id=land_id)
        if crop_id:
            qs = qs.filter(crop_id=crop_id)
        return qs


class YieldDetailView(generics.RetrieveAPIView):
    serializer_class = YieldDetailSerializer
    lookup_field = 'yield_id'

    def get_queryset(self):
        allowed = _allowed_farm_ids(self.request)
        return Yields.objects.filter(
            yield_status=1,
            deleted_at__isnull=True,
            farm_id__in=allowed,
        )


class YieldCreateView(generics.CreateAPIView):
    queryset = Yields.objects.all()
    serializer_class = YieldCreateSerializer
    permission_classes = [IsGestorOrReadOnly]

    def create(self, request, *args, **kwargs):
        farm_id = request.data.get('farm')
        if not farm_id:
            return Response(
                {'farm': ['Este campo é obrigatório.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        allowed = _allowed_farm_ids(request)
        try:
            farm_id_int = int(farm_id)
        except (TypeError, ValueError):
            return Response(
                {'farm': ['ID de exploração inválido.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if farm_id_int not in allowed:
            return Response(
                {'detail': 'Sem acesso a esta exploração.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        return super().create(request, *args, **kwargs)


def _apply_nutrient_fields(obj, data, fields):
    for field in fields:
        if field in data:
            value = data.get(field)
            if value == '':
                value = None
            setattr(obj, field, value)


# ─────────── Foliar analysis ───────────

class YieldAnalysisCreateView(APIView):
    """POST /yields/<yield_id>/analyses/create/ — criar análise foliar."""
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request, yield_id):
        try:
            yield_obj = Yields.objects.get(yield_id=yield_id, deleted_at__isnull=True)
        except Yields.DoesNotExist:
            return Response(
                {'detail': 'Cultura não encontrada.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if yield_obj.farm_id not in _allowed_farm_ids(request):
            return Response(
                {'detail': 'Sem acesso a esta exploração.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        date = request.data.get('yield_analysis_date')
        sample = request.data.get('yield_analysis_sample')
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
            rel_path = os.path.join('yield_analyses', str(yield_id), filename).replace('\\', '/')
            full_path = os.path.join(settings.MEDIA_ROOT, rel_path)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, 'wb+') as f:
                for chunk in pdf.chunks():
                    f.write(chunk)

        analysis = YieldsAnalysis(
            yield_field=yield_obj,
            yield_analysis_date=date,
            yield_analysis_sample=sample,
            yield_analysis_file=rel_path,
            created_at=timezone.now(),
            created_by=request.user.user_id,
        )
        _apply_nutrient_fields(analysis, request.data, YIELD_NUTRIENT_FIELDS)
        analysis.save()

        return Response(
            YieldAnalysisSerializer(analysis).data,
            status=status.HTTP_201_CREATED,
        )


class YieldAnalysisListView(generics.ListAPIView):
    serializer_class = YieldAnalysisSerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        yield_id = self.kwargs.get('yield_id')
        return YieldsAnalysis.objects.filter(
            yield_field_id=yield_id,
            deleted_at__isnull=True,
        ).order_by('-yield_analysis_date')


class YieldAnalysisDetailView(APIView):
    """GET/PATCH/DELETE /yields/analyses/<id>/"""
    permission_classes = [IsFarmMember]

    def _get(self, analysis_id):
        try:
            return YieldsAnalysis.objects.get(
                yield_analysis_id=analysis_id, deleted_at__isnull=True,
            )
        except YieldsAnalysis.DoesNotExist:
            return None

    def get(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(YieldAnalysisSerializer(a).data)

    def patch(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        if 'yield_analysis_date' in request.data:
            a.yield_analysis_date = request.data['yield_analysis_date']
        if 'yield_analysis_sample' in request.data:
            a.yield_analysis_sample = request.data['yield_analysis_sample']
        _apply_nutrient_fields(a, request.data, YIELD_NUTRIENT_FIELDS)
        a.updated_at = timezone.now()
        a.updated_by = request.user.user_id
        a.save()
        return Response(YieldAnalysisSerializer(a).data)

    def delete(self, request, analysis_id):
        a = self._get(analysis_id)
        if not a:
            return Response(status=status.HTTP_404_NOT_FOUND)
        a.deleted_at = timezone.now()
        a.deleted_by = request.user.user_id
        a.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class YieldAnalysisPDFView(APIView):
    permission_classes = [IsFarmMember]

    def get(self, request, analysis_id):
        try:
            a = YieldsAnalysis.objects.get(
                yield_analysis_id=analysis_id, deleted_at__isnull=True,
            )
        except YieldsAnalysis.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        yield_name = ''
        try:
            yield_name = a.yield_field.yield_name
        except Exception:
            pass

        try:
            data = foliar_analysis_pdf(a, yield_name=yield_name)
        except Exception as e:
            import logging, traceback
            logging.error(
                '[YieldAnalysisPDF] erro a gerar PDF id=%s: %s\n%s',
                analysis_id, e, traceback.format_exc(),
            )
            return Response(
                {'detail': f'Erro a gerar PDF: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        response = HttpResponse(data, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'inline; filename="analise_foliar_{a.yield_analysis_id}.pdf"'
        )
        return response


# ─────────── Harvests ───────────

def _set_harvest_fields(obj, data):
    for field in HARVEST_FIELDS:
        if field in data:
            value = data.get(field)
            if value == '':
                value = None
            setattr(obj, field, value)


class HarvestListView(generics.ListAPIView):
    serializer_class = HarvestSerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        yield_id = self.kwargs.get('yield_id')
        return YieldsHarvests.objects.filter(
            yield_field_id=yield_id,
            deleted_at__isnull=True,
        ).order_by('-harvest_date')


class HarvestCreateView(APIView):
    permission_classes = [IsFarmMember]

    def post(self, request, yield_id):
        try:
            yield_obj = Yields.objects.get(yield_id=yield_id, deleted_at__isnull=True)
        except Yields.DoesNotExist:
            return Response(
                {'detail': 'Cultura não encontrada.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if yield_obj.farm_id not in _allowed_farm_ids(request):
            return Response(
                {'detail': 'Sem acesso a esta exploração.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        date = request.data.get('harvest_date')
        name = request.data.get('harvest_name')
        harvested = request.data.get('harvest_harvested')
        if not date or not name or harvested in (None, ''):
            return Response(
                {'detail': 'Data, nome e quantidade são obrigatórios.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        harvest = YieldsHarvests(
            yield_field=yield_obj,
            created_at=timezone.now(),
            created_by=request.user.user_id,
        )
        _set_harvest_fields(harvest, request.data)
        if not harvest.unit_measurement:
            harvest.unit_measurement = 'KG'
        harvest.save()
        return Response(HarvestSerializer(harvest).data, status=status.HTTP_201_CREATED)


class HarvestDetailView(APIView):
    permission_classes = [IsFarmMember]

    def _get(self, harvest_id):
        try:
            return YieldsHarvests.objects.get(
                harvest_id=harvest_id, deleted_at__isnull=True,
            )
        except YieldsHarvests.DoesNotExist:
            return None

    def get(self, request, harvest_id):
        h = self._get(harvest_id)
        if not h:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(HarvestSerializer(h).data)

    def patch(self, request, harvest_id):
        h = self._get(harvest_id)
        if not h:
            return Response(status=status.HTTP_404_NOT_FOUND)
        _set_harvest_fields(h, request.data)
        h.updated_at = timezone.now()
        h.updated_by = request.user.user_id
        h.save()
        return Response(HarvestSerializer(h).data)

    def delete(self, request, harvest_id):
        h = self._get(harvest_id)
        if not h:
            return Response(status=status.HTTP_404_NOT_FOUND)
        h.deleted_at = timezone.now()
        h.deleted_by = request.user.user_id
        h.save()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HarvestPDFView(APIView):
    permission_classes = [IsFarmMember]

    def get(self, request, harvest_id):
        try:
            h = YieldsHarvests.objects.get(
                harvest_id=harvest_id, deleted_at__isnull=True,
            )
        except YieldsHarvests.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        yield_name = ''
        try:
            yield_name = h.yield_field.yield_name
        except Exception:
            pass

        try:
            data = harvest_pdf(h, yield_name=yield_name)
        except Exception as e:
            import logging, traceback
            logging.error(
                '[HarvestPDF] erro a gerar PDF id=%s: %s\n%s',
                harvest_id, e, traceback.format_exc(),
            )
            return Response(
                {'detail': f'Erro a gerar PDF: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        response = HttpResponse(data, content_type='application/pdf')
        response['Content-Disposition'] = (
            f'inline; filename="colheita_{h.harvest_id}.pdf"'
        )
        return response
