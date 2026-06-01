from django.urls import path
from .views import (
    FarmListView, FarmDetailView, FarmCreateView,
    CompanyCreateView,
    InviteGenerateView, InviteJoinView, InviteListView, InviteCancelView,
    AccessPendingView, AccessApproveView,
)

urlpatterns = [
    # Farms
    path('', FarmListView.as_view(), name='farm-list'),
    path('<int:farm_id>/', FarmDetailView.as_view(), name='farm-detail'),
    path('create/', FarmCreateView.as_view(), name='farm-create'),

    # Company
    path('company/create/', CompanyCreateView.as_view(), name='company-create'),

    # Convites
    path('<int:farm_id>/invite/generate/', InviteGenerateView.as_view(), name='invite-generate'),
    path('invite/join/', InviteJoinView.as_view(), name='invite-join'),
    path('invite/list/', InviteListView.as_view(), name='invite-list'),
    path('invite/<int:invite_id>/cancel/', InviteCancelView.as_view(), name='invite-cancel'),

    # Pedidos de acesso
    path('access/pending/', AccessPendingView.as_view(), name='access-pending'),
    path('access/<int:row_id>/action/', AccessApproveView.as_view(), name='access-action'),
]