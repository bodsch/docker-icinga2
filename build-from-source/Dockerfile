
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
    autoconf \
    automake \
    build-base \
    boost-dev \
    bison \
    cmake \
    curl \
    flex \
    git \
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
    boost \
    boost-program_options

RUN \
  git clone https://github.com/monitoring-plugins/monitoring-plugins.git

RUN \
  cd /build/monitoring-plugins/ && \
  sed -i 's|sys/poll.h|poll.h|' plugins/common.h && \
  sed -i 's|sys/poll.h|poll.h|' plugins-root/check_dhcp.c && \
  ./tools/setup && \
  ./configure \
    --libexecdir="/usr/lib/monitoring-plugins" \
    --prefix=/usr \
    --without-ipv6 \
    --with-openssl \
    --with-pgsql=/usr \
    --with-mysql  \
    --with-fping-command=$(which fping) \
    --with-nslookup-command=$(which nslookup)

RUN \
  cd /build/monitoring-plugins/ && \
  # fix this:
  # ar: `u' modifier ignored since `D' is the default (see `U')
  # see: https://bugzilla.redhat.com/show_bug.cgi?id=1155273#c13
  export ARFLAGS='cr' && \
  export AR_FLAGS='cr' && \
  find . -name "*apt*" | xargs -r rm -rf && \
  make && \
  make install

  # checking for ICMP ping syntax... /bin/ping -n -U -w %d -c %d %s

#RUN \
#  curl \
#    --silent \
#    --location \
#    --retry 3 \
#    --cacert /etc/ssl/certs/ca-certificates.crt \
#    "https://github.com/Icinga/icinga2/archive/v${ICINGA_VERSION}.tar.gz" \
#    | gunzip \
#    | tar x -C /build
#
#RUN \
#  addgroup -g 1000 icinga && \
#  addgroup -g 1001 icingacmd && \
#  adduser -D -H -G icinga -g '' -u 1000 -h /var/lib/icinga2 -s /sbin/nologin icinga && \
#  usermod -a -G icingacmd icinga
#
## RUN \
##   mkdir -p /etc/icinga2 && \
##   mkdir -p /var/log/icinga2 && \
##   mkdir -p /var/lib/icinga2/api/zones && \
##   mkdir -p /var/lib/icinga2/api/repository && \
##   mkdir -p /var/lib/icinga2/api/log && \
##   mkdir -p /var/cache/icinga2 && \
##   mkdir -p /var/spool/icinga2/perfdata
#
#RUN \
#  cd /build/icinga2-${ICINGA_VERSION} && \
#  mkdir build && \
#  cd build && \
#  cmake .. \
#    -DCMAKE_VERBOSE_MAKEFILE=OFF \
#    -DCMAKE_BUILD_TYPE=Release \
#    -DCMAKE_INSTALL_PREFIX=/usr \
#    -DCMAKE_INSTALL_SYSCONFDIR=/etc \
#    -DCMAKE_INSTALL_SBINDIR=/usr/sbin \
#    -DCMAKE_INSTALL_LIBDIR=/usr/lib \
#    -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
#    -DICINGA2_WITH_COMPAT=OFF \
#    -DICINGA2_WITH_LIVESTATUS=OFF \
#    -DICINGA2_GIT_VERSION_INFO=OFF \
#    -DICINGA2_RUNDIR=/run \
#    -DICINGA2_SYSCONFIGFILE=/etc/icinga2 \
#    -DICINGA2_PLUGINDIR=/usr/lib/monitoring-plugins \
#    -DICINGA2_LTO_BUILD=ON && \
#  make --silent --jobs=2
#
#RUN \
#  chown root:icinga /etc/icinga2 && \
#  chmod 0750 /etc/icinga2 && \
#  chown icinga:icinga /var/lib/icinga2 && \
#  chown icinga:icinga /var/spool/icinga2 && \
#  chown -R icinga:icingacmd /var/lib/icinga2/api && \
#  chown icinga:icinga /var/spool/icinga2/perfdata && \
#  chown icinga:icinga /var/cache/icinga2 && \
#  chown icinga:icingacmd /var/log/icinga2 && \
#  chmod ug+rwX,o-rwx /etc/icinga2 && \
#  chmod ug+rwX,o-rwx /var/lib/icinga2 && \
#  chmod ug+rwX,o-rwx /var/spool/icinga2 && \
#  chmod ug+rwX,o-rwx /var/log/icinga2
#
#RUN \
#  cd /build/icinga2-${ICINGA_VERSION}/build && \
#  make config && \
#  make install && \
#  cp -ar /usr/etc/icinga2/* /etc/icinga2/

#RUN \
#  which icinga2 && \
#  icinga2 --version

#RUN \
#  apk del --quiet .build-deps && \
#  rm -rf \
#    /tmp/* \
#    /var/cache/apk/*

# WORKDIR /etc/icinga2

CMD [ "/bin/sh" ]

