from django.urls import path
from .views import (
    LandListView,
    LandDetailView,
    LandCreateView,
    LandIrrigationView,
    SoilAnalysisCreateView,
    SoilAnalysisListView,
    SoilAnalysisDetailView,
    SoilAnalysisPDFView,
)

urlpatterns = [
    path('', LandListView.as_view(), name='land-list'),
    path('create/', LandCreateView.as_view(), name='land-create'),
    path('<int:land_id>/', LandDetailView.as_view(), name='land-detail'),
    path('<int:land_id>/irrigation/', LandIrrigationView.as_view(), name='land-irrigation'),
    path(
        '<int:land_id>/soil-analyses/',
        SoilAnalysisListView.as_view(),
        name='land-soil-analysis-list',
    ),
    path(
        '<int:land_id>/soil-analyses/create/',
        SoilAnalysisCreateView.as_view(),
        name='land-soil-analysis-create',
    ),
    path(
        'soil-analyses/<int:analysis_id>/',
        SoilAnalysisDetailView.as_view(),
        name='soil-analysis-detail',
    ),
    path(
        'soil-analyses/<int:analysis_id>/pdf/',
        SoilAnalysisPDFView.as_view(),
        name='soil-analysis-pdf',
    ),
]
