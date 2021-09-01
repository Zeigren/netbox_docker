ARG VERSION
ARG DATE
ARG NEXTBOX

FROM python:alpine AS build

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV APP_ROOT="/usr/src/app"
ENV APP_HOME="/usr/src/app/netbox"
ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV APP_REPO="https://github.com/netbox-community/netbox"

RUN apk add --no-cache \
    gcc jpeg-dev libffi-dev libxslt-dev libxml2-dev musl-dev openssl-dev \
    postgresql-dev python3-dev zlib-dev libwebp-dev

ARG VERSION

RUN wget -qO archive.tar.gz $APP_REPO/archive/$VERSION.tar.gz \
    && mkdir -p $APP_ROOT \
    && tar --strip-components=1 -C $APP_ROOT -xf archive.tar.gz \
    && rm archive.tar.gz \
    && python -m venv $VIRTUAL_ENV \
    && pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -U -r /usr/src/app/requirements.txt

ARG NEXTBOX

RUN if [ $NEXTBOX = true ]; \
    then pip install --no-cache-dir nextbox-ui-plugin ; fi


FROM python:alpine AS production

ENV PYTHONUNBUFFERED 1
ENV APP_ROOT="/usr/src/app"
ENV APP_HOME="/usr/src/app/netbox"
ENV VIRTUAL_ENV="/opt/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN apk add --no-cache postgresql-libs libjpeg-turbo libwebp \
    && addgroup -g 1000 docker \
    && adduser --disabled-password --gecos "" --home $APP_HOME --ingroup docker --no-create-home --uid 1000 docker \
    && mkdir -p /usr/src/media /usr/src/app/netbox/static \
    && chown -R docker:docker /usr/src/media /usr/src/app/netbox/static

COPY --from=build $VIRTUAL_ENV $VIRTUAL_ENV
COPY --chown=1000:1000 --from=build $APP_ROOT $APP_ROOT
COPY env_secrets_expand.sh docker-entrypoint.sh /

RUN chmod +x /env_secrets_expand.sh \
    && chmod +x /docker-entrypoint.sh

USER docker

WORKDIR $APP_HOME

VOLUME /usr/src/app/netbox/static /usr/src/media

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["gunicorn", "-c", "gunicorn.conf.py", "netbox.wsgi"]

ARG VERSION
ARG DATE
ARG NEXTBOX
ENV NEXTBOX=$NEXTBOX

LABEL org.opencontainers.image.created=$DATE \
    org.opencontainers.image.authors="Zeigren" \
    org.opencontainers.image.url="https://github.com/Zeigren/netbox_docker" \
    org.opencontainers.image.source="https://github.com/Zeigren/netbox_docker" \
    org.opencontainers.image.version=$VERSION \
    org.opencontainers.image.title="zeigren/netbox"
