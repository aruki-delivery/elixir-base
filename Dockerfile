FROM arm64v8/elixir:1.8.2-alpine

MAINTAINER Carlos Brito Lage <cbl@aruki.pt>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT "2019-04-17-0403"
ENV REPLACE_OS_VARS "true"
ENV HOME "/opt/app/"
# Set this so that CTRL+G works properly
ENV TERM "xterm"

RUN \
    apk --no-cache --update upgrade && \
    apk add --no-cache bash alpine-sdk coreutils imagemagick icu-dev zlib zlib-dev && \
    which magick && \
    magick -version

## Cleanup
RUN rm -rf /var/cache/apk/* &&  \
    rm -rf /tmp/* &&  \
    rm -rf /var/log/*

## Build Output
RUN echo "Erlang/OTP Version:"
RUN erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell
RUN echo "Elixir Version:"
RUN iex -v


CMD ["/bin/sh"]
