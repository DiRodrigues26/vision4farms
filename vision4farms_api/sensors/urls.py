from django.urls import path

from .views import (
    SensorAssociationBulkView,
    SensorAssociationDetailView,
    SensorAssociationListView,
)


urlpatterns = [
    path('associations/', SensorAssociationListView.as_view(), name='sensor-association-list'),
    path('associations/bulk/', SensorAssociationBulkView.as_view(), name='sensor-association-bulk'),
    path('associations/<int:association_id>/', SensorAssociationDetailView.as_view(), name='sensor-association-detail'),
]
