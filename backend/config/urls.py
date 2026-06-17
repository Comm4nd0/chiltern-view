from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("tracker.urls")),
    path("api-auth/", include("rest_framework.urls")),
]

# In local dev (no nginx) let Django serve uploaded media. In Docker, nginx
# serves /media/ from the shared volume instead.
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
