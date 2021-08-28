ARG VERSION
ARG DATE
ARG NEXTBOX

FROM python:alpine AS build

ARG VERSION
ARG NEXTBOX

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV APP_ROOT="/usr/src/app"
ENV APP_HOME="/usr/src/app/netbox"
ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV APP_REPO="https://github.com/netbox-community/netbox.git"

RUN apk add --no-cache \
    gcc git jpeg-dev libffi-dev libxslt-dev libxml2-dev musl-dev openssl-dev \
    postgresql-dev python3-dev zlib-dev

RUN git clone --branch ${VERSION} --depth 1 ${APP_REPO} ${APP_ROOT} \
    && python -m venv $VIRTUAL_ENV \
    && pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -U -r /usr/src/app/requirements.txt \
    && if [ $NEXTBOX = True ]; \
    then pip install --no-cache-dir nextbox-ui-plugin ; fi


FROM python:alpine AS production

ARG VERSION
ARG DATE
ARG NEXTBOX

LABEL org.opencontainers.image.created=$DATE \
    org.opencontainers.image.authors="Zeigren" \
    org.opencontainers.image.url="https://github.com/Zeigren/netbox_docker" \
    org.opencontainers.image.source="https://github.com/Zeigren/netbox_docker" \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.title="zeigren/netbox"

ENV PYTHONUNBUFFERED 1
ENV APP_ROOT="/usr/src/app"
ENV APP_HOME="/usr/src/app/netbox"
ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV NEXTBOX=$NEXTBOX

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=build $APP_ROOT $APP_ROOT

RUN apk add --no-cache postgresql-client py3-pillow

COPY env_secrets_expand.sh docker-entrypoint.sh /

RUN chmod +x /env_secrets_expand.sh \
    && chmod +x /docker-entrypoint.sh

WORKDIR ${APP_HOME}

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["gunicorn", "-c", "gunicorn.conf.py", "netbox.wsgi"]
