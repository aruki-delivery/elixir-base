FROM alpine:3.8 as builder

MAINTAINER Carlos Brito Lage <cbl@aruki.pt>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2018-07-27-211411 \
    LANG=en_US.UTF-8 \
    HOME=/opt/app/ \
    # Set this so that CTRL+G works properly
    TERM=xterm \
    ERLANG_VERSION=21.0.4 \
    ELIXIR_VERSION=v1.6.6

RUN rm -rf /opt/erlang/build && \
    rm -rf /opt/elixir/build && \
    mkdir -p /opt/erlang/build && \
    mkdir -p /opt/elixir/build

WORKDIR /tmp/erlang-build

# Install Erlang
RUN \
    # Create default user and home directory, set owner to default
    mkdir -p "${HOME}" && \
    adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    # Add tagged repos as well as the edge repo so that we can selectively install edge packages
    echo "@main http://dl-cdn.alpinelinux.org/alpine/v3.8/main" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.8/community" >> /etc/apk/repositories && \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Upgrade Alpine and base packages
    apk --no-cache upgrade && \
    # Distillery requires bash
    apk add --no-cache bash@edge && \
    # Install Erlang/OTP deps
    apk add --no-cache pcre@edge && \
    apk add --no-cache \
      alpine-sdk@edge \
      ca-certificates@edge \
      openssl-dev@edge \
      ncurses-dev@edge \
      unixodbc-dev@edge \
      zlib-dev@edge \
      dpkg-dev@edge \
      dpkg@edge \
      git@edge \
      autoconf@edge \
      build-base@edge \
      perl-dev@edge && \
      # Update ca certificates
      update-ca-certificates --fresh && \
      # Shallow clone Erlang/OTP
      git clone -b OTP-$ERLANG_VERSION --single-branch --depth 1 https://github.com/erlang/otp.git .

RUN \
    # Erlang/OTP build env
    export ERL_TOP=/tmp/erlang-build && \
    export PATH=$ERL_TOP/bin:$PATH && \
    export CPPFlAGS="-D_BSD_SOURCE $CPPFLAGS" && \
    # Configure
    ./otp_build autoconf && \
    ./configure --prefix=/usr \
      --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
      --sysconfdir=/etc \
      --mandir=/usr/share/man \
      --infodir=/usr/share/info \
      --without-javac \
      --without-wx \
      --without-debugger \
      --without-observer \
      --without-jinterface \
      --without-cosEvent\
      --without-cosEventDomain \
      --without-cosFileTransfer \
      --without-cosNotification \
      --without-cosProperty \
      --without-cosTime \
      --without-cosTransactions \
      --without-et \
      --without-gs \
      --without-ic \
      --without-megaco \
      --without-orber \
      --without-percept \
      --without-typer \
      --enable-threads \
      --enable-shared-zlib \
      --enable-ssl=dynamic-ssl-lib \
      --enable-dialyzer \
      --enable-hipe \
      --prefix=/opt/erlang/build && \
    # Build
    make -j4 && make install

RUN \
    ln -s /opt/erlang/build/bin/ct_run /usr/local/bin/ct_run && \
    ln -s /opt/erlang/build/bin/dialyzer /usr/local/bin/dialyzer && \
    ln -s /opt/erlang/build/bin/epmd /usr/local/bin/epmd && \
    ln -s /opt/erlang/build/bin/erl /usr/local/bin/erl && \
    ln -s /opt/erlang/build/bin/erlc /usr/local/bin/erlc && \
    ln -s /opt/erlang/build/bin/escript /usr/local/bin/escript && \
    ln -s /opt/erlang/build/bin/run_erl /usr/local/bin/run_erl && \
    ln -s /opt/erlang/build/bin/to_erl /usr/local/bin/to_erl && \
    ln -s /opt/erlang/build/bin/typer /usr/local/bin/typer


## Intall Elixir

WORKDIR /tmp/elixir-build

RUN \
    git clone https://github.com/elixir-lang/elixir --depth 1 --branch $ELIXIR_VERSION && \
    cd elixir && \
    make && make install PREFIX=/opt/elixir/build

RUN \
    ln -s /opt/elixir/build/bin/elixir /usr/local/bin/elixir && \
    ln -s /opt/elixir/build/bin/elixirc /usr/local/bin/elixirc && \
    ln -s /opt/elixir/build/bin/iex /usr/local/bin/iex && \
    ln -s /opt/elixir/build/bin/mix /usr/local/bin/mix

RUN \
    mix local.hex --force && \
    mix local.rebar --force


########
## Actual Docker image that's gonna run inside docker:
########
FROM alpine:3.8

RUN \
    # Create default user and home directory, set owner to default
    mkdir -p "${HOME}" && \
    adduser -s /bin/sh -u 1001 -G root -h "${HOME}" -S -D default && \
    chown -R 1001:0 "${HOME}" && \
    # Add tagged repos as well as the edge repo so that we can selectively install edge packages
    echo "@main http://dl-cdn.alpinelinux.org/alpine/v3.8/main" >> /etc/apk/repositories && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/v3.8/community" >> /etc/apk/repositories && \
    echo "@edge http://nl.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Upgrade Alpine and base packages
    apk --no-cache upgrade && \
    # Install Erlang/OTP deps
    apk add --no-cache \
      unixodbc-dev@edge \
      zlib-dev@edge \
      openssl-dev@edge \
      ca-certificates@edge \
      ncurses-dev@edge \
      bash@edge && \
      # Update ca certificates
      update-ca-certificates --fresh

RUN rm -rf /opt/ && \
    mkdir -p /opt/elixir/build && \
    mkdir -p /opt/erlang/build

## Copy build from builder image
COPY --from=builder /opt/erlang/build/ /opt/erlang/build
COPY --from=builder /opt/elixir/build/ /opt/elixir/build

RUN \
    ln -s /opt/erlang/build/bin/ct_run /usr/local/bin/ct_run && \
    ln -s /opt/erlang/build/bin/dialyzer /usr/local/bin/dialyzer && \
    ln -s /opt/erlang/build/bin/epmd /usr/local/bin/epmd && \
    ln -s /opt/erlang/build/bin/erl /usr/local/bin/erl && \
    ln -s /opt/erlang/build/bin/erlc /usr/local/bin/erlc && \
    ln -s /opt/erlang/build/bin/escript /usr/local/bin/escript && \
    ln -s /opt/erlang/build/bin/run_erl /usr/local/bin/run_erl && \
    ln -s /opt/erlang/build/bin/to_erl /usr/local/bin/to_erl && \
    ln -s /opt/erlang/build/bin/typer /usr/local/bin/typer && \
    ln -s /opt/elixir/build/bin/elixir /usr/local/bin/elixir && \
    ln -s /opt/elixir/build/bin/elixirc /usr/local/bin/elixirc && \
    ln -s /opt/elixir/build/bin/iex /usr/local/bin/iex && \
    ln -s /opt/elixir/build/bin/mix /usr/local/bin/mix

## Cleanup
RUN rm -rf /var/cache/apk/* &&  \
    rm -rf /tmp/* &&  \
    rm -rf /var/log/* && \
    rm -rf ${HOME}/.mix

RUN echo "Erlang/OTP Version:"
RUN erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell
RUN echo "Elixir Version:"
RUN iex -v

CMD ["/bin/sh"]
