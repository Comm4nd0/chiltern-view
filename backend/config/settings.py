"""Django settings for the chiltern_view backend.

Configuration is driven by environment variables so the same image runs both
locally (SQLite, DEBUG on) and on the Luma001 Docker host (Postgres, DEBUG off).
"""
from pathlib import Path
import os

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name, default=False):
    return os.environ.get(name, str(default)).lower() in ("1", "true", "yes", "on")


def env_list(name, default=""):
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]


# --- Core -------------------------------------------------------------------
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-insecure-change-me")
# Default OFF: a missing/typo'd env var must never leave DEBUG on in production
# (it would leak tracebacks and settings). Local dev sets DJANGO_DEBUG=True.
DEBUG = env_bool("DJANGO_DEBUG", False)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "*" if DEBUG else "")
if DEBUG and not ALLOWED_HOSTS:
    ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "rest_framework.authtoken",
    "django_filters",
    "corsheaders",
    # Local
    "tracker",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# --- Database ---------------------------------------------------------------
# Local default is SQLite; in Docker DATABASE_URL points at Postgres.
DATABASES = {
    "default": dj_database_url.config(
        default=os.environ.get("DATABASE_URL", f"sqlite:///{BASE_DIR / 'db.sqlite3'}"),
        conn_max_age=600,
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# --- Locale -----------------------------------------------------------------
LANGUAGE_CODE = "en-gb"
TIME_ZONE = os.environ.get("DJANGO_TIME_ZONE", "Europe/London")
USE_I18N = True
USE_TZ = True

# --- Static files -----------------------------------------------------------
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": (
            "django.contrib.staticfiles.storage.StaticFilesStorage"
            if DEBUG
            else "whitenoise.storage.CompressedManifestStaticFilesStorage"
        )
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Django REST Framework --------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.OrderingFilter",
        "rest_framework.filters.SearchFilter",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    # The API is internet-facing (via Caddy), so it is locked down by default:
    # every endpoint needs a token except the few that opt out with AllowAny
    # (health probe, login). Clients send `Authorization: Token <key>` and drop
    # to the login screen on a 401. Home Assistant authenticates with a token too
    # — see docs/HOME_ASSISTANT.md.
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
}

# --- CORS / CSRF ------------------------------------------------------------
# The Flutter app talks to this API cross-origin (especially Flutter web in dev).
CORS_ALLOW_ALL_ORIGINS = env_bool("CORS_ALLOW_ALL_ORIGINS", DEBUG)
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS", "")
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS", "")

# --- Weather (Open-Meteo) for crop watering reminders -----------------------
# Baked in to the holding's location: Medmenham, Buckinghamshire.
WEATHER_LATITUDE = float(os.environ.get("WEATHER_LATITUDE", "51.557"))
WEATHER_LONGITUDE = float(os.environ.get("WEATHER_LONGITUDE", "-0.812"))
WEATHER_LOCATION_NAME = os.environ.get("WEATHER_LOCATION_NAME", "Medmenham, Buckinghamshire")
# How long a fetched forecast stays fresh before re-fetching on demand.
WEATHER_CACHE_MINUTES = int(os.environ.get("WEATHER_CACHE_MINUTES", "30"))
# Rain (mm, fallen in the last 2 days or confidently forecast today) at or above
# which crop-watering reminders are deferred for the day.
WATERING_RAIN_THRESHOLD_MM = float(os.environ.get("WATERING_RAIN_THRESHOLD_MM", "5"))
# Overnight minimum (°C) below which the dashboard warns about tender crops.
FROST_TEMP_C = float(os.environ.get("FROST_TEMP_C", "2"))

# --- Web push reminders (VAPID) ----------------------------------------------
# The browser equivalent of the phone app's on-device reminders. Generate a
# keypair once (npx web-push generate-vapid-keys) and set these in the server's
# .env; leave them empty to disable web push.
VAPID_PUBLIC_KEY = os.environ.get("VAPID_PUBLIC_KEY", "")
VAPID_PRIVATE_KEY = os.environ.get("VAPID_PRIVATE_KEY", "")
VAPID_CLAIMS_EMAIL = os.environ.get("VAPID_CLAIMS_EMAIL", "admin@example.com")
# Local hour (Europe/London) after which the daily reminder push goes out —
# mirrors the phone app's default 8am digest.
PUSH_REMINDER_HOUR = int(os.environ.get("PUSH_REMINDER_HOUR", "8"))

# --- HTTPS hardening --------------------------------------------------------
# Caddy terminates TLS and reverse-proxies plain HTTP to the container, so trust
# its X-Forwarded-Proto to know the original request was HTTPS.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
# Opt-in (DJANGO_SECURE_HTTPS=True) once the site is reachable only over HTTPS:
# redirect HTTP→HTTPS, mark cookies secure, and turn on HSTS. Kept off by default
# so the in-container healthcheck and direct-LAN HTTP access keep working until
# the deployment is ready for it.
SECURE_HTTPS = env_bool("DJANGO_SECURE_HTTPS", False)
if SECURE_HTTPS:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = int(os.environ.get("DJANGO_HSTS_SECONDS", str(60 * 60 * 24 * 7)))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = False
    SECURE_HSTS_PRELOAD = False
    # The Docker healthcheck curls http://localhost:8000/ — let it through.
    SECURE_REDIRECT_EXEMPT = [r"^api/health/?$"]
