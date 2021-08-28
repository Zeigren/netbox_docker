#!/bin/sh

. /env_secrets_expand.sh

set -e

# Generate new secret if none is provided
if [ -z "${SECRET_KEY}" ]; then
    SECRET_KEY=$(tr </dev/urandom -cd 'a-zA-Z0-9' | head -c 50)
fi

if [ ! -f "$APP_HOME/netbox/configuration.py" ]; then
    echo "creating configuration.py"
    cat >"$APP_HOME/netbox/configuration.py" <<EOF

from os import getenv

ALLOWED_HOSTS = ['${ALLOWED_HOSTS:-netbox.yourdomain.test}']

DATABASE = {
    'NAME': 'netbox',
    'USER': 'netbox',
    'PASSWORD': '${DATABASE_PASSWORD:-CHANGEME}',
    'HOST': 'postgres',
    'PORT': '',
    'CONN_MAX_AGE': 300,
}

REDIS = {
    'tasks': {
        'HOST': 'redis',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 0,
        'SSL': False,
    },
    'caching': {
        'HOST': 'redis',
        'PORT': 6379,
        'PASSWORD': '',
        'DATABASE': 1,
        'SSL': False,
    }
}

SECRET_KEY = '${SECRET_KEY}'

ADMINS = [
    # ['John Doe', 'jdoe@example.com'],
]

ALLOWED_URL_SCHEMES = (
    'file', 'ftp', 'ftps', 'http', 'https', 'irc', 'mailto', 'sftp', 'ssh', 'tel', 'telnet', 'tftp', 'vnc', 'xmpp',
)

BANNER_TOP = '${BANNER_TOP}'
BANNER_BOTTOM = '${BANNER_BOTTOM}'

BANNER_LOGIN = '${BANNER_LOGIN}'

BASE_PATH = ''

CACHE_TIMEOUT = 0

CHANGELOG_RETENTION = 90

CORS_ORIGIN_ALLOW_ALL = False
CORS_ORIGIN_WHITELIST = [
    # 'https://hostname.example.com',
]
CORS_ORIGIN_REGEX_WHITELIST = [
    # r'^(https?://)?(\w+\.)?example\.com$',
]

DEBUG = False

EMAIL = {
    'SERVER': '${EMAIL_SERVER:-localhost}',
    'PORT': ${EMAIL_PORT:-25},
    'USERNAME': '${EMAIL_USERNAME}',
    'PASSWORD': '${EMAIL_PASSWORD}',
    'USE_SSL': ${EMAIL_USE_SSL:-False},
    'USE_TLS': ${EMAIL_USE_TLS:-False},
    'TIMEOUT': ${EMAIL_TIMEOUT:-10},  # seconds
    'FROM_EMAIL': '${EMAIL_FROM_EMAIL}',
}

ENFORCE_GLOBAL_UNIQUE = ${ENFORCE_GLOBAL_UNIQUE:-False}

EXEMPT_VIEW_PERMISSIONS = [ 
    ${EXEMPT_VIEW_PERMISSIONS}
    # 'dcim.site',
    # 'dcim.region',
    # 'ipam.prefix',
]

INTERNAL_IPS = ('127.0.0.1', '::1')

LOGGING = {}

LOGIN_PERSISTENCE = ${LOGIN_PERSISTENCE:-False}

LOGIN_REQUIRED = ${LOGIN_REQUIRED:-False}

LOGIN_TIMEOUT = ${LOGIN_TIMEOUT:-None}

MAINTENANCE_MODE = ${MAINTENANCE_MODE:-False}

MAPS_URL = '${MAPS_URL:-https://maps.google.com/?q=}'

MAX_PAGE_SIZE = ${MAX_PAGE_SIZE:-1000}

MEDIA_ROOT = '/usr/src/media'

METRICS_ENABLED = ${METRICS_ENABLED:-True}

NAPALM_USERNAME = ''
NAPALM_PASSWORD = ''

NAPALM_TIMEOUT = 30

NAPALM_ARGS = {}

PAGINATE_COUNT = ${PAGINATE_COUNT:-50}

if getenv('NEXTBOX'):
  PLUGINS = [
    'nextbox_ui_plugin',
    ]
else:
  PLUGINS = []

PREFER_IPV4 = ${PREFER_IPV4:-False}

RACK_ELEVATION_DEFAULT_UNIT_HEIGHT = 22
RACK_ELEVATION_DEFAULT_UNIT_WIDTH = 220

REMOTE_AUTH_ENABLED = False
REMOTE_AUTH_BACKEND = 'netbox.authentication.RemoteUserBackend'
REMOTE_AUTH_HEADER = 'HTTP_REMOTE_USER'
REMOTE_AUTH_AUTO_CREATE_USER = True
REMOTE_AUTH_DEFAULT_GROUPS = []
REMOTE_AUTH_DEFAULT_PERMISSIONS = {}

RELEASE_CHECK_TIMEOUT = 24 * 3600

RELEASE_CHECK_URL = None

RQ_DEFAULT_TIMEOUT = 300

SESSION_COOKIE_NAME = 'sessionid'

SESSION_FILE_PATH = None

TIME_ZONE = '${TIME_ZONE:-UTC}'

DATE_FORMAT = 'N j, Y'
SHORT_DATE_FORMAT = 'Y-m-d'
TIME_FORMAT = 'g:i a'
SHORT_TIME_FORMAT = 'H:i:s'
DATETIME_FORMAT = 'N j, Y g:i a'
SHORT_DATETIME_FORMAT = 'Y-m-d H:i'
EOF
fi

if [ ! -f "$APP_HOME/gunicorn.conf.py" ]; then
    echo "Creating gunicorn.conf.py"
    # https://docs.gunicorn.org/en/stable/configure.html
    cat >"$APP_HOME/gunicorn.conf.py" <<EOF
import multiprocessing

bind = "0.0.0.0:8000"

workers = ${GUNICORN_WORKERS:-multiprocessing.cpu_count() * 2}

timeout = 120
max_requests = 1000
max_requests_jitter = 50
EOF
fi

echo "Running database migrations and collecting static files"
python manage.py migrate --noinput
python manage.py trace_paths --no-input
python manage.py collectstatic --noinput
python manage.py remove_stale_contenttypes --no-input
python manage.py clearsessions
python manage.py invalidate all
echo "Static files collected and database migrations completed!"

if [ "$CREATE_SUPERUSER" = "True" ]; then
    echo "Creating superuser"
    python manage.py createsuperuser --noinput
fi

echo "Running rqworker"
nohup python manage.py rqworker >/dev/null 2>&1 &

exec "$@"
