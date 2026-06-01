from django.urls import path
from .water_views import (
    WaterSourceTypeListView,
    WaterIrrigationMethodListView,
    WaterSourceListCreateView,
    WaterSourceDetailView,
    WaterUsageLogListCreateView,
    WaterUsageLogDetailView,
    WaterIrrigationPlannedListCreateView,
    WaterIrrigationPlannedDetailView,
    WaterIrrigationPlannedExecuteView,
)

urlpatterns = [
    # Lookups
    path('types/',   WaterSourceTypeListView.as_view(),       name='water-types'),
    path('methods/', WaterIrrigationMethodListView.as_view(), name='water-methods'),

    # Water Sources
    path('sources/',                              WaterSourceListCreateView.as_view(), name='water-source-list'),
    path('sources/<int:water_source_id>/',        WaterSourceDetailView.as_view(),     name='water-source-detail'),

    # Usage Logs
    path('usage-logs/',                           WaterUsageLogListCreateView.as_view(), name='water-usage-list'),
    path('usage-logs/<int:water_usage_id>/',      WaterUsageLogDetailView.as_view(),     name='water-usage-detail'),

    # Planned Irrigations
    path('planned/',                              WaterIrrigationPlannedListCreateView.as_view(), name='water-planned-list'),
    path('planned/<int:planned_id>/',             WaterIrrigationPlannedDetailView.as_view(),     name='water-planned-detail'),
    path('planned/<int:planned_id>/execute/',     WaterIrrigationPlannedExecuteView.as_view(),    name='water-planned-execute'),
]
