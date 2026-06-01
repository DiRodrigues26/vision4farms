import os
import uuid
from django.conf import settings
from rest_framework import generics, status
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView
from farms.permissions import IsFarmMember, IsGestorOrReadOnly, IsOwnerOrGestor
from .models import Activities, Observations
from .serializers import ActivitySerializer, ActivityCreateSerializer, ObservationSerializer


class ActivityListView(generics.ListAPIView):
    serializer_class = ActivitySerializer
    permission_classes = [IsFarmMember]

    def get_queryset(self):
        qs = Activities.objects.filter(deleted_at__isnull=True).order_by('activity_date_planned')
        farm_id = self.request.query_params.get('farm_id')
        land_id = self.request.query_params.get('land_id')
        status = self.request.query_params.get('status')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        if land_id:
            qs = qs.filter(land_id=land_id)
        if status is not None:
            qs = qs.filter(activity_status=status)
        return qs


class ActivityDetailView(generics.RetrieveUpdateAPIView):
    queryset = Activities.objects.filter(deleted_at__isnull=True)
    serializer_class = ActivitySerializer
    lookup_field = 'activity_id'
    permission_classes = [IsOwnerOrGestor]


class ActivityCreateView(generics.CreateAPIView):
    queryset = Activities.objects.all()
    serializer_class = ActivityCreateSerializer
    permission_classes = [IsGestorOrReadOnly]


class ObservationListView(generics.ListCreateAPIView):
    serializer_class = ObservationSerializer

    def get_queryset(self):
        qs = Observations.objects.filter(deleted_at__isnull=True).order_by('-created_at')
        land_id = self.request.query_params.get('land_id')
        farm_id = self.request.query_params.get('farm_id')
        if land_id:
            qs = qs.filter(land_id=land_id)
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        return qs


class ObservationImageUploadView(APIView):
    """Upload de foto para uma observação. Guarda o ficheiro e atualiza observation_photo."""
    parser_classes = [MultiPartParser]

    def post(self, request, observation_id):
        try:
            obs = Observations.objects.get(
                observation_id=observation_id, deleted_at__isnull=True
            )
        except Observations.DoesNotExist:
            return Response(
                {'detail': 'Observação não encontrada.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        photo = request.FILES.get('photo')
        if not photo:
            return Response(
                {'detail': 'Nenhuma imagem enviada.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Guardar em media/observations/<observation_id>/<uuid>.<ext>
        ext = os.path.splitext(photo.name)[1] or '.jpg'
        filename = f'{uuid.uuid4().hex}{ext}'
        rel_path = os.path.join('observations', str(observation_id), filename)
        full_path = os.path.join(settings.MEDIA_ROOT, rel_path)

        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, 'wb+') as f:
            for chunk in photo.chunks():
                f.write(chunk)

        # Guardar path relativo na BD
        obs.observation_photo = rel_path
        obs.updated_by = request.user.user_id
        obs.save(update_fields=['observation_photo', 'updated_by', 'updated_at'])

        photo_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{rel_path}')
        return Response({'observation_photo': photo_url}, status=status.HTTP_200_OK)
