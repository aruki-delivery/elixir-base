# aruki/elixir-base

Base Docker image for our Elixir-based services.

https://cloud.docker.com/swarm/aruki/repository/docker/aruki/elixir-base/general


# Usage

```Dockerfile
## Builder image that prepares the build and puts it in the Docker image that runs:
FROM aruki/elixir-base:v21.0.2-1.6.6-20180704220547 as builder

MAINTAINER Carlos Brito Lage <cbl@aruki.pt>

ENV REPLACE_OS_VARS "true"

ENV ARUKI_PG_DB "xxx"
ENV ARUKI_PG_USER "xxx"
ENV ARUKI_PG_PASS "xxx"
ENV ARUKI_PG_HOST "xxx"

ENV ARUKI_REDIS_HOST "xxx"
ENV ARUKI_REDIS_PASSWORD "xxx"
ENV ARUKI_REDIS_POOL "50"

ENV ARUKI_PASSWORD_RESET_KEY "xxxxxx"
ENV ARUKI_PASSWORD_RESET_TOKEN_EXPIRE_MINUTES "5"

ENV SENDGRID_API_KEY "xxxxx"

ENV APP_NAME "phoenix_swarm"

ENV MIX_ENV "prod"

RUN \
    apk --no-cache --update upgrade && \
    apk add --no-cache alpine-sdk && \
    which make

RUN rm -rf /opt/app
RUN mkdir -p /opt/app \
    /opt/app/_build \
    /opt/app/deps \
    /opt/app/.mix \
    /opt/app/config \
    /opt/app/apps/aruki_api \
    /opt/app/apps/aruki_cache \
    /opt/app/apps/aruki_database \
    /opt/app/apps/aruki_lib \
    /opt/app/apps/aruki_media_server \
    /opt/app/rel

WORKDIR /opt/app

# ez cache ez build
COPY mix.exs .
COPY mix.lock .
COPY apps/aruki_api/mix.exs apps/aruki_api/
COPY apps/aruki_cache/mix.exs apps/aruki_cache/
COPY apps/aruki_database/mix.exs apps/aruki_database/
COPY apps/aruki_lib/mix.exs apps/aruki_lib/
COPY apps/aruki_media_server/mix.exs apps/aruki_media_server/
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix compile

COPY openapi.yaml .
COPY rel rel/
COPY config config/
COPY apps/aruki_api apps/aruki_api/
COPY apps/aruki_cache apps/aruki_cache/
COPY apps/aruki_database apps/aruki_database/
COPY apps/aruki_lib apps/aruki_lib/
COPY apps/aruki_media_server/ apps/aruki_media_server/

# Compile & Release
RUN mix release

#Extract Release archive to /rel for copying in next stage
RUN RELEASE_DIR=`ls -d ./_build/$MIX_ENV/rel/$APP_NAME/releases/*/` && \
    mkdir /export && \
    tar -xf "$RELEASE_DIR/$APP_NAME.tar.gz" -C /export

########
## Actual Docker image that's gonna run inside docker:
########
FROM aruki/elixir-base:media-server-v21.0.2-1.6.6-20180704220547

## Copy build from builder image
RUN rm -rf /opt/app
RUN mkdir -p /opt/app
WORKDIR /opt/app
COPY --from=builder /export/ .

## Cleanup
RUN rm -rf /var/cache/apk/* &&  \
    rm -rf /tmp/* &&  \
    rm -rf /var/log/*

# Expose ports: API, Healthcheck, OAuth, and MediaServer
EXPOSE 8899
EXPOSE 8900
EXPOSE 8901
EXPOSE 8902

# Set default entrypoint and command
ENTRYPOINT ["bin/phoenix_swarm"]
CMD ["foreground"]
```

# License
The Aruki Elixir Docker base images are available under the [BSD 3-Clause aka "BSD New" license](http://www.tldrlegal.com/l/BSD3)
