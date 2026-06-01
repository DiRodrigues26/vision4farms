from django.utils import timezone
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from farms.permissions import IsFarmMember, IsGestorOrReadOnly, IsOwnerOrGestor
from .models import Agenda
from .serializers import AgendaSerializer, AgendaCreateSerializer


class AgendaListView(generics.ListAPIView):
    serializer_class = AgendaSerializer
    permission_classes = [IsFarmMember]
    pagination_class = None  # dados do mês completo

    def get_queryset(self):
        qs = Agenda.objects.filter(deleted_at__isnull=True).order_by('agenda_date', 'agenda_time_start')
        farm_id = self.request.query_params.get('farm_id')
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        agenda_status = self.request.query_params.get('status')
        agenda_type = self.request.query_params.get('type')
        land_id = self.request.query_params.get('land_id')
        if farm_id:
            qs = qs.filter(farm_id=farm_id)
        if date_from:
            qs = qs.filter(agenda_date__gte=date_from)
        if date_to:
            qs = qs.filter(agenda_date__lte=date_to)
        if agenda_status is not None:
            qs = qs.filter(agenda_status=agenda_status)
        if agenda_type:
            qs = qs.filter(agenda_type=agenda_type)
        if land_id:
            qs = qs.filter(land_id=land_id)
        return qs


class AgendaCreateView(generics.CreateAPIView):
    queryset = Agenda.objects.all()
    serializer_class = AgendaCreateSerializer
    permission_classes = [IsGestorOrReadOnly]


class AgendaDetailView(generics.RetrieveUpdateAPIView):
    queryset = Agenda.objects.filter(deleted_at__isnull=True)
    serializer_class = AgendaSerializer
    lookup_field = 'agenda_id'
    permission_classes = [IsOwnerOrGestor]

    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user.user_id)


class AgendaDeleteView(APIView):
    permission_classes = [IsGestorOrReadOnly]
    def delete(self, request, agenda_id):
        try:
            agenda = Agenda.objects.get(agenda_id=agenda_id, deleted_at__isnull=True)
        except Agenda.DoesNotExist:
            return Response({'detail': 'Evento não encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        agenda.deleted_at = timezone.now()
        agenda.deleted_by = request.user.user_id
        agenda.save(update_fields=['deleted_at', 'deleted_by'])
        return Response(status=status.HTTP_204_NO_CONTENT)
