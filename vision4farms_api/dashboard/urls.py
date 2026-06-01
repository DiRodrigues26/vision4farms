from django.urls import path
from .views import DashboardView, DashboardFarmsView

urlpatterns = [
    path('farms/', DashboardFarmsView.as_view(), name='dashboard-farms'),
    path('<int:farm_id>/', DashboardView.as_view(), name='dashboard'),
]
