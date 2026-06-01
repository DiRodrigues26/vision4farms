from django.urls import path
from .views import (
    YieldListView,
    YieldDetailView,
    YieldCreateView,
    YieldAnalysisCreateView,
    YieldAnalysisListView,
    YieldAnalysisDetailView,
    YieldAnalysisPDFView,
    HarvestListView,
    HarvestCreateView,
    HarvestDetailView,
    HarvestPDFView,
)

urlpatterns = [
    path('', YieldListView.as_view(), name='yield-list'),
    path('create/', YieldCreateView.as_view(), name='yield-create'),
    path('<int:yield_id>/', YieldDetailView.as_view(), name='yield-detail'),

    # Foliar analyses
    path(
        '<int:yield_id>/analyses/',
        YieldAnalysisListView.as_view(),
        name='yield-analysis-list',
    ),
    path(
        '<int:yield_id>/analyses/create/',
        YieldAnalysisCreateView.as_view(),
        name='yield-analysis-create',
    ),
    path(
        'analyses/<int:analysis_id>/',
        YieldAnalysisDetailView.as_view(),
        name='yield-analysis-detail',
    ),
    path(
        'analyses/<int:analysis_id>/pdf/',
        YieldAnalysisPDFView.as_view(),
        name='yield-analysis-pdf',
    ),

    # Harvests
    path(
        '<int:yield_id>/harvests/',
        HarvestListView.as_view(),
        name='harvest-list',
    ),
    path(
        '<int:yield_id>/harvests/create/',
        HarvestCreateView.as_view(),
        name='harvest-create',
    ),
    path(
        'harvests/<int:harvest_id>/',
        HarvestDetailView.as_view(),
        name='harvest-detail',
    ),
    path(
        'harvests/<int:harvest_id>/pdf/',
        HarvestPDFView.as_view(),
        name='harvest-pdf',
    ),
]
