from django.urls import path
from .views import (
    LoginView, RegisterView, RefreshView,
    MeView, LogoutView,
    PasswordResetRequestView, PasswordResetConfirmView,
    ProfileUpdateView, ProfilePictureUploadView, PasswordChangeView,
    password_reset_page,
)

urlpatterns = [
    path('login/', LoginView.as_view(), name='login'),
    path('register/', RegisterView.as_view(), name='register'),
    path('refresh/', RefreshView.as_view(), name='token_refresh'),
    path('me/', MeView.as_view(), name='me'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('password-reset/', PasswordResetRequestView.as_view(), name='password-reset'),
    path('password-reset/confirm/', PasswordResetConfirmView.as_view(), name='password-reset-confirm'),
    path('profile/', ProfileUpdateView.as_view(), name='profile-update'),
    path('profile/picture/', ProfilePictureUploadView.as_view(), name='profile-picture-upload'),
    path('password-change/', PasswordChangeView.as_view(), name='password-change'),
]