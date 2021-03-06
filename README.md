# Docker Stack For [NetBox](https://github.com/netbox-community/netbox)

![Docker Image Size (latest)](https://img.shields.io/docker/image-size/zeigren/netbox/latest)
![Docker Pulls](https://img.shields.io/docker/pulls/zeigren/netbox)

## Links

### [Docker Hub](https://hub.docker.com/r/zeigren/netbox)

### [ghcr.io](https://ghcr.io/zeigren/netbox_docker)

### [GitHub](https://github.com/Zeigren/netbox_docker)

## Tags

- latest, latest-nextbox
- v2.11.12, v2.11.12-nextbox
- v2.11.10
- v2.11.9

## Stack

- Python:Alpine - NetBox
- Caddy or NGINX - web server
- Postgres:Alpine - database
- Redis:Alpine - cache

## Usage

Use [Docker Compose](https://docs.docker.com/compose/) or [Docker Swarm](https://docs.docker.com/engine/swarm/) to deploy. Containers are available from both Docker Hub and the GitHub Container Registry.

There are examples for using either [Caddy](https://caddyserver.com/) or [NGINX](https://www.nginx.com/) as the web server and examples for using Caddy, NGINX, or [Traefik](https://traefik.io/traefik/) for HTTPS (the Traefik example also includes using it as a reverse proxy). The NGINX examples are in the nginx folder.

The images that end in `-nextbox` have the [nextbox-ui-plugin](https://github.com/iDebugAll/nextbox-ui-plugin) installed.

## Recommendations

I recommend using Caddy as the web server and either have it handle HTTPS or pair it with Traefik as they both have native [ACME](https://en.wikipedia.org/wiki/Automated_Certificate_Management_Environment) support for automatically getting HTTPS certificates from [Let's Encrypt](https://letsencrypt.org/) or will create self signed certificates for local use.

If you can I also recommend using [Docker Swarm](https://docs.docker.com/engine/swarm/) over [Docker Compose](https://docs.docker.com/compose/) as it supports [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) and [Docker Configs](https://docs.docker.com/engine/swarm/configs/).

If Caddy doesn't work for you or you are chasing performance then checkout the NGINX examples. I haven't done any performance testing but NGINX has a lot of configurability which may let you squeeze out better performance if you have a lot of users, also check the performance section below.

## Configuration

Configuration consists of setting environment variables in the `.yml` files. More environment variables for configuring [NetBox](https://netbox.readthedocs.io/en/stable/configuration/) can be found in `docker-entrypoint.sh` and for Caddy in `netbox_caddyfile`.

Setting the `DOMAIN` variable changes whether Caddy uses HTTP, HTTPS with a self signed certificate, or HTTPS with a certificate from Let's Encrypt or ZeroSSL. Check the Caddy [documentation](https://caddyserver.com/docs/automatic-https) for more info.

On first run you'll need to create a superuser by setting the relevant environment variables in the `.yml` files.

### [Docker Swarm](https://docs.docker.com/engine/swarm/)

I personally use this with [Traefik](https://traefik.io/) as a reverse proxy, I've included an example `traefik.yml` but it's not necessary.

You'll need to create the appropriate [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) and [Docker Configs](https://docs.docker.com/engine/swarm/configs/).

Any environment variables for NetBox in `docker-entrypoint.sh` can instead be set using Docker Secrets, there's an example of how to do this in the relevant `.yml` files.

Run with `docker stack deploy --compose-file docker-swarm.yml netbox`

### [Docker Compose](https://docs.docker.com/compose/)

Run with `docker-compose -f docker-compose.yml up -d`. View using `127.0.0.1:9080`.

### Performance Tuning

The web servers set the relevant HTTP headers to have browsers cache as much as they can for as long as they can while requiring browsers to check if those files have changed, this is to get the benefit of caching without having to deal with the caches potentially serving old content. If content doesn't change that often or can be invalidated in another way then this behavior can be changed to reduce the number of requests.

The number of [workers](https://docs.gunicorn.org/en/stable/settings.html#workers) Gunicorn uses can be set with the `GUNICORN_WORKERS` environment variable.

## Theory of operation

The [Dockerfile](https://docs.docker.com/engine/reference/builder/) uses [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/) creating a build container that has all the dependencies for the python packages which are installed into a [python virtual environment](https://docs.python.org/3/tutorial/venv.html). The production container copies the python virtual environment from the build container and runs NetBox from there, this allows it to be much more lightweight.

On startup, the container first runs the `docker-entrypoint.sh` script before running `gunicorn`.

`docker-entrypoint.sh` creates configuration files and runs commands based on environment variables that are declared in the various `.yml` files.

`env_secrets_expand.sh` handles using Docker Secrets.

## File Permissions

If using docker volumes and the default user (`docker` with a UID and GID of `1000`) you shouldn't need to do anything. However if you run the container as a different [user](https://docs.docker.com/compose/compose-file/compose-file-v3/#domainname-hostname-ipc-mac_address-privileged-read_only-shm_size-stdin_open-tty-user-working_dir) or have any permissions issues you may need to change the permissions for `usr/src/app/netbox/static` and `/usr/src/media`.

One way to change the permissions would be to the change the [entrypoint](https://docs.docker.com/compose/compose-file/compose-file-v3/#entrypoint) for the NetBox container in the `.yml` file to `entrypoint: sleep 900m` and attach to the container as `root` and run `chown -R docker:docker /usr/src/app/netbox/static /usr/src/media`, or instead of attaching to the container you could run `docker exec -it --user root NETBOX_CONTAINER /bin/sh -c "chown -R docker:docker /usr/src/app/netbox/static /usr/src/media"`
