from django.urls import path
from .views import AgendaListView, AgendaCreateView, AgendaDetailView, AgendaDeleteView

urlpatterns = [
    path('', AgendaListView.as_view(), name='agenda-list'),
    path('create/', AgendaCreateView.as_view(), name='agenda-create'),
    path('<int:agenda_id>/', AgendaDetailView.as_view(), name='agenda-detail'),
    path('<int:agenda_id>/delete/', AgendaDeleteView.as_view(), name='agenda-delete'),
]
