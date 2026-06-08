#!/bin/sh
set -e

echo "Applying database migrations..."
python manage.py migrate --noinput

# Optionally bootstrap an admin user from environment variables.
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
  echo "Ensuring superuser '$DJANGO_SUPERUSER_USERNAME' exists..."
  python manage.py createsuperuser --noinput || true
fi

exec "$@"
