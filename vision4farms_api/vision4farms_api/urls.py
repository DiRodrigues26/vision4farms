from django.conf import settings
from django.conf.urls.static import static
from django.urls import path, include, re_path
from django.http import JsonResponse
from django.views.static import serve
from authentication.views import password_reset_page


def app_status(request):
    """GET /api/status/ — estado da app (manutenção e versão mínima)."""
    return JsonResponse({
        'maintenance': False,
        'min_version': '1.0.0',
        'store_url': '',
    })


urlpatterns = [
    path('api/status/',        app_status, name='app-status'),
    path('api/auth/',          include('authentication.urls')),
    path('api/farms/',         include('farms.urls')),
    path('api/lands/',         include('lands.urls')),
    path('api/crops/',         include('crops.urls')),
    path('api/activities/',    include('activities.urls')),
    path('api/notifications/', include('notifications_app.urls')),
    path('api/dashboard/',     include('dashboard.urls')),
    path('api/map/',           include('map.urls')),          # ← NOVO
    # Página HTML de reset de password (acedida pelo link do email)
    path('reset-password/', password_reset_page, name='reset-password-page'),
    path('api/yields/',        include('yields_app.urls')),  # ← NOVO
    path('api/agenda/',        include('agenda.urls')),
    path('api/water/',         include('lands.water_urls')),
    path('api/sensors/',       include('sensors.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    # Em produção também queremos servir /media/ (fotos de observações,
    # PDFs de análises, etc.). Não usamos S3, então o Django serve.
    urlpatterns += [
        re_path(
            r'^media/(?P<path>.*)$',
            serve,
            {'document_root': settings.MEDIA_ROOT},
        ),
    ]
