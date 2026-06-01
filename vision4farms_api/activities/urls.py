from django.urls import path
from .views import (
    ActivityListView, ActivityDetailView, ActivityCreateView,
    ObservationListView, ObservationImageUploadView,
)

urlpatterns = [
    path('', ActivityListView.as_view(), name='activity-list'),
    path('create/', ActivityCreateView.as_view(), name='activity-create'),
    path('<int:activity_id>/', ActivityDetailView.as_view(), name='activity-detail'),
    path('observations/', ObservationListView.as_view(), name='observation-list'),
    path('observations/<int:observation_id>/upload/',
         ObservationImageUploadView.as_view(), name='observation-image-upload'),
]
