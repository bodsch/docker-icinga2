
FROM alpine:3.7 as builder

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  BUILD_DATE="2018-02-01" \
  ICINGA_VERSION="2.8.1"

WORKDIR /build

RUN \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    build-base \
    boost \
    boost-dev \
    bison \
    cmake \
    flex \
    libressl-dev \
    libffi-dev \
    mariadb-dev \
    postgresql-dev \
    shadow && \
  apk add --quiet --no-cache \
    curl git

RUN \
  curl \
    --silent \
    --location \
    --retry 3 \
    --cacert /etc/ssl/certs/ca-certificates.crt \
    "https://github.com/Icinga/icinga2/archive/v${ICINGA_VERSION}.tar.gz" \
    | gunzip \
    | tar x -C /build

RUN \
  addgroup -g 1000 icinga && \
  addgroup -g 1001 icingacmd && \
  adduser -D -H -G icinga -g '' -u 1000 -h /var/lib/icinga2 -s /sbin/nologin icinga && \
  usermod -a -G icingacmd icinga

RUN \
  mkdir -p /etc/icinga2 && \
  mkdir -p /var/log/icinga2 && \
  mkdir -p /var/lib/icinga2/api/zones && \
  mkdir -p /var/lib/icinga2/api/repository && \
  mkdir -p /var/lib/icinga2/api/log && \
  mkdir -p /var/spool/icinga2/perfdata && \
  mkdir -p /usr/share/icinga2/include/plugins

RUN \
  chown root:icinga /etc/icinga2 && \
  chmod 0750 /etc/icinga2 && \
  chown icinga:icinga /var/lib/icinga2 && \
  chown icinga:icinga /var/spool/icinga2 && \
  chown -R icinga:icingacmd /var/lib/icinga2/api && \
  chown icinga:icinga /var/spool/icinga2/perfdata && \
  chown icinga:icingacmd /var/log/icinga2 && \
  chmod ug+rwX,o-rwx /etc/icinga2 && \
  chmod ug+rwX,o-rwx /var/lib/icinga2 && \
  chmod ug+rwX,o-rwx /var/spool/icinga2 && \
  chmod ug+rwX,o-rwx /var/log/icinga2

RUN \
  cd /build/icinga2-${ICINGA_VERSION} && \
  mkdir build && \
  cd build && \
  cmake .. \
    -DICINGA2_UNITY_BUILD=FALSE \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_BUILD_TYPE=None \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc \
    -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
    -DICINGA2_SYSCONFIGFILE=/etc/conf.d/icinga2 \
    -DICINGA2_PLUGINDIR="/usr/share/icinga2/include/plugins" \
    -DICINGA2_USER=icinga \
    -DICINGA2_GROUP=icingacmd \
    -DICINGA2_COMMAND_GROUP=icingacmd \
    -DINSTALL_SYSTEMD_SERVICE_AND_INITSCRIPT=no \
    -DLOGROTATE_HAS_SU=OFF \
    -DICINGA2_WITH_MYSQL=ON \
    -DICINGA2_WITH_PGSQL=ON \
    -DICINGA2_LTO_BUILD=ON \
    -DICINGA2_WITH_STUDIO=OFF && \
  make

RUN \
  cd /build/icinga2-${ICINGA_VERSION}/build && \
  make install


CMD [ "/bin/sh" ]

