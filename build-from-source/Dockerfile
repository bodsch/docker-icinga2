
FROM alpine:3.7 as builder

ARG BUILD_DATE
ARG ICINGA2_VERSION
ARG ICINGA2_VCS_REF

ENV \
  TZ='Europe/Berlin'

WORKDIR /build

RUN \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    autoconf \
    automake \
    build-base \
    boost-dev \
    bison \
    cmake \
    curl \
    flex \
    git \
    libdbi-dev \
    openldap-dev \
    net-snmp-dev \
    libressl-dev \
    libedit-dev \
    mariadb-dev \
    postgresql-dev \
    gettext-dev \
    perl-dev \
    yajl-dev \
    shadow && \
  apk add --quiet --no-cache \
    file \
    fping \
    samba-client \
    net-snmp-tools \
    iputils \
    libedit \
    yajl \
    gettext \
    mariadb-client \
    mariadb-client-libs \
    postgresql-client \
    boost \
    boost-program_options

RUN \
  echo "export BUILD_DATE=${BUILD_DATE}" > /etc/enviroment

RUN \
  git clone https://github.com/monitoring-plugins/monitoring-plugins.git && \
  cd /build/monitoring-plugins/ && \
  # should fix this:
  # ar: `u' modifier ignored since `D' is the default (see `U')
  # see: https://bugzilla.redhat.com/show_bug.cgi?id=1155273#c13
  export ARFLAGS='cr' && \
  export AR_FLAGS='cr' && \
  sed -i 's|sys/poll.h|poll.h|' plugins/common.h && \
  sed -i 's|sys/poll.h|poll.h|' plugins-root/check_dhcp.c && \
  ./tools/setup && \
  ./configure \
    --libexecdir="/usr/lib/monitoring-plugins" \
    --prefix=/usr \
    --without-ipv6 \
    --with-pgsql=/usr \
    --with-mysql  \
    --with-fping-command=$(which fping) \
    --with-nslookup-command=$(which nslookup) && \
  make --silent --jobs=2 && \
  make install --silent

#RUN \
#  cd /build && \
#  curl \
#    --silent \
#    --location \
#    --retry 3 \
#    --cacert /etc/ssl/certs/ca-certificates.crt \
#    "https://github.com/Icinga/icinga2/archive/v${ICINGA2_VERSION}.tar.gz" \
#    | gunzip \
#    | tar x -C /build

RUN \
  cd /build && \
  git clone https://github.com/Icinga/icinga2.git && \
  mv icinga2 icinga2-${ICINGA2_VERSION} && \
  cd icinga2-${ICINGA2_VERSION} && \
  git checkout support/2.8

RUN \
  cd /build/icinga2-${ICINGA2_VERSION} && \
  mkdir build && \
  cd build && \
  cmake .. \
    -DCMAKE_VERBOSE_MAKEFILE=OFF \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc \
    -DCMAKE_INSTALL_SBINDIR=/usr/sbin \
    -DCMAKE_INSTALL_LIBDIR=/usr/lib \
    -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
    -DICINGA2_WITH_COMPAT=ON \
    -DICINGA2_WITH_LIVESTATUS=ON \
    -DICINGA2_GIT_VERSION_INFO=OFF \
    -DICINGA2_RUNDIR=/run \
    -DICINGA2_SYSCONFIGFILE=/etc/icinga2 \
    -DICINGA2_PLUGINDIR=/usr/lib/monitoring-plugins \
    -DICINGA2_LTO_BUILD=ON && \
  make --silent --jobs=2 && \
  cd /build/icinga2-${ICINGA2_VERSION}/build && \
  make config && \
  make install


RUN \
  cp -ar /usr/etc/icinga2/* /etc/icinga2/ && \
  rm -f /etc/icinga2/features-enabled/*

CMD [ "/bin/sh" ]

# ---------------------------------------------------------------------------------------

FROM alpine:3.7

COPY --from=builder /usr/lib/monitoring-plugins /usr/lib/monitoring-plugins
COPY --from=builder /etc/icinga2 /etc/icinga2
COPY --from=builder /usr/lib/icinga2 /usr/lib/icinga2
COPY --from=builder /usr/share/icinga2 /usr/share/icinga2
COPY --from=builder /usr/sbin/icinga2 /usr/sbin/icinga2
COPY --from=builder /usr/share/icinga2-ido-mysql /usr/share/icinga2-ido-mysql
COPY --from=builder /usr/share/icinga2-ido-pgsql /usr/share/icinga2-ido-pgsql
# COPY --from=builder /usr/lib/monitoring-plugins/check_nscp_api /usr/lib/monitoring-plugins/check_nscp_api
COPY --from=builder /var/lib/icinga2 /var/lib/icinga2
COPY --from=builder /var/spool/icinga2 /var/spool/icinga2
COPY --from=builder /var/cache/icinga2 /var/cache/icinga2
COPY --from=builder /var/log/icinga2 /var/log/icinga2
COPY --from=builder /etc/enviroment /etc/enviroment

RUN \
  if [ -f /etc/enviroment ] ; then . /etc/enviroment; fi && \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    shadow && \
  apk add --quiet --no-cache \
    file \
    fping \
    samba-client \
    net-snmp-tools \
    iputils \
    libedit \
    yajl \
    gettext \
    mariadb-client \
    mariadb-client-libs \
    postgresql-client \
    boost \
    boost-program_options && \
  addgroup -g 1000 icinga && \
  addgroup -g 1001 icingacmd && \
  adduser -D -H -G icinga -g '' -u 1000 -h /var/lib/icinga2 -s /sbin/nologin icinga && \
  usermod -a -G icingacmd icinga && \
  chown root:icinga /etc/icinga2 && \
  chmod 0750 /etc/icinga2 && \
  chown icinga:icinga /var/lib/icinga2 && \
  chown icinga:icinga /var/spool/icinga2 && \
  chown -R icinga:icingacmd /var/lib/icinga2/api && \
  chown icinga:icinga /var/spool/icinga2/perfdata && \
  chown icinga:icinga /var/cache/icinga2 && \
  chown icinga:icingacmd /var/log/icinga2 && \
  chmod ug+rwX,o-rwx /etc/icinga2 && \
  chmod ug+rwX,o-rwx /var/lib/icinga2 && \
  chmod ug+rwX,o-rwx /var/spool/icinga2 && \
  chmod ug+rwX,o-rwx /var/log/icinga2 && \
  apk del --quiet .build-deps && \
  echo "" && \
  which icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo "" && \
  rm -rf \
    /tmp/* \
    /build \
    /var/cache/apk/* \
    /var/cache/icinga2/*

WORKDIR /etc/icinga2

CMD [ "/init/run.sh" ]

