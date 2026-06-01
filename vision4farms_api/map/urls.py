from django.urls import path
from .views import MapDataView

urlpatterns = [
    path('<int:farm_id>/', MapDataView.as_view(), name='map-data'),
]
