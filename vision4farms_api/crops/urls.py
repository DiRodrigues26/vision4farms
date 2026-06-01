from django.urls import path
from .views import CropListView, CropDetailView, CropHubView, CropFarmListView

urlpatterns = [
    path('', CropListView.as_view(), name='crop-list'),
    path('farm/<int:farm_id>/', CropFarmListView.as_view(), name='crop-farm-list'),
    path('<int:crop_id>/', CropDetailView.as_view(), name='crop-detail'),
    path('<int:crop_id>/hub/', CropHubView.as_view(), name='crop-hub'),
]
