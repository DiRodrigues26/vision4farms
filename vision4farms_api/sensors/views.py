from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from farms.permissions import ROLE_GESTOR, _get_user_role
from lands.models import Lands
from .models import SensorNodeAssociation
from .serializers import (
    SensorAssociationBulkSerializer,
    SensorNodeAssociationSerializer,
)


def _land_belongs_to_farm(land_id, farm_id):
    return Lands.objects.filter(
        land_id=land_id,
        current_farm_id=farm_id,
        deleted_at__isnull=True,
    ).exists()


class SensorAssociationListView(APIView):
    """GET /sensors/associations/?farm_id=<id>&land_id=<id opcional>"""

    def get(self, request):
        farm_id = request.query_params.get('farm_id')
        land_id = request.query_params.get('land_id')

        if not farm_id and land_id:
            try:
                land = Lands.objects.get(
                    land_id=land_id,
                    deleted_at__isnull=True,
                )
                farm_id = land.current_farm_id
            except Lands.DoesNotExist:
                return Response(
                    {'detail': 'Terreno não encontrado.'},
                    status=status.HTTP_404_NOT_FOUND,
                )

        if not farm_id:
            return Response(
                {'detail': 'farm_id é obrigatório.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        role = _get_user_role(request.user, int(farm_id))
        if role is None:
            return Response(
                {'detail': 'Não tem acesso a esta exploração.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        qs = SensorNodeAssociation.objects.filter(
            farm_id=farm_id,
            deleted_at__isnull=True,
        ).order_by('sensor_nome')
        if land_id:
            qs = qs.filter(land_id=land_id)

        return Response(SensorNodeAssociationSerializer(qs, many=True).data)


class SensorAssociationBulkView(APIView):
    """POST /sensors/associations/bulk/"""

    def post(self, request):
        serializer = SensorAssociationBulkSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        farm_id = serializer.validated_data['farm_id']
        role = _get_user_role(request.user, farm_id)
        if role != ROLE_GESTOR:
            return Response(
                {'detail': 'Apenas gestores podem associar sensores.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        saved = []
        for item in serializer.validated_data['associations']:
            land_id = item['land_id']
            if not _land_belongs_to_farm(land_id, farm_id):
                return Response(
                    {'detail': f'O terreno {land_id} não pertence à exploração.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            values = {
                'land_id': land_id,
                'gateway_code': item['gateway_code'].upper(),
                'sensor_no_id': item.get('sensor_no_id') or None,
                'sensor_nome': item['sensor_nome'],
                'sensor_tipo': item.get('sensor_tipo') or None,
                'sensor_status': item.get('sensor_status') or None,
                'ultimo_contacto': item.get('ultimo_contacto') or None,
                'updated_at': timezone.now(),
                'updated_by': request.user.user_id,
            }

            association = (
                SensorNodeAssociation.objects
                .filter(
                    farm_id=farm_id,
                    sensor_firebase_id=item['sensor_firebase_id'],
                    deleted_at__isnull=True,
                )
                .first()
            )
            if association:
                for field, value in values.items():
                    setattr(association, field, value)
                association.save()
            else:
                association = SensorNodeAssociation.objects.create(
                    farm_id=farm_id,
                    sensor_firebase_id=item['sensor_firebase_id'],
                    created_at=timezone.now(),
                    created_by=request.user.user_id,
                    **values,
                )
            saved.append(association)

        return Response(
            SensorNodeAssociationSerializer(saved, many=True).data,
            status=status.HTTP_201_CREATED,
        )


class SensorAssociationDetailView(APIView):
    """PATCH/DELETE /sensors/associations/<association_id>/"""

    def _get_association(self, association_id):
        try:
            return SensorNodeAssociation.objects.get(
                association_id=association_id,
                deleted_at__isnull=True,
            )
        except SensorNodeAssociation.DoesNotExist:
            return None

    def patch(self, request, association_id):
        association = self._get_association(association_id)
        if not association:
            return Response(status=status.HTTP_404_NOT_FOUND)

        role = _get_user_role(request.user, association.farm_id)
        if role != ROLE_GESTOR:
            return Response(
                {'detail': 'Apenas gestores podem alterar associações.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        land_id = request.data.get('land_id')
        if land_id is not None:
            if not _land_belongs_to_farm(int(land_id), association.farm_id):
                return Response(
                    {'detail': 'Terreno inválido para esta exploração.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            association.land_id = int(land_id)

        for field in (
            'sensor_no_id',
            'sensor_nome',
            'sensor_tipo',
            'sensor_status',
            'ultimo_contacto',
        ):
            if field in request.data:
                setattr(association, field, request.data.get(field) or None)

        association.updated_at = timezone.now()
        association.updated_by = request.user.user_id
        association.save()
        return Response(SensorNodeAssociationSerializer(association).data)

    def delete(self, request, association_id):
        association = self._get_association(association_id)
        if not association:
            return Response(status=status.HTTP_404_NOT_FOUND)

        role = _get_user_role(request.user, association.farm_id)
        if role != ROLE_GESTOR:
            return Response(
                {'detail': 'Apenas gestores podem remover associações.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        association.deleted_at = timezone.now()
        association.deleted_by = request.user.user_id
        association.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
