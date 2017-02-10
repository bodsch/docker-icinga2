
FROM bodsch/docker-alpine-base:1701-04

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1702-02"
LABEL date="2017-02-10"

ENV TERM xterm

EXPOSE 5665 6666

# ---------------------------------------------------------------------------------------

RUN \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add \
    build-base \
    bind-tools \
    ruby \
    ruby-dev \
    git \
    pwgen \
    fping \
    unzip \
    netcat-openbsd \
    nmap \
    bc \
    jq \
    yajl-tools \
    ssmtp \
    mailx \
    mysql-client \
    icinga2 \
    openssl \
    openssl-dev \
    monitoring-plugins \
    nrpe-plugin && \
  gem install --no-rdoc --no-ri \
    dalli \
    sequel \
    ipaddress \
    json \
    time_difference \
    bigdecimal \
    io-console \
    thin \
    sinatra \
    sinatra-basic-auth \
    openssl && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  cp /usr/lib/nagios/plugins/*     /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command livestatus compatlog checker mainlog && \
  mkdir -p /etc/icinga2/automatic-zones.d && \
  mkdir -p /run/icinga2/cmd && \
  chmod u+s /bin/busybox && \
  cd /tmp && \
  git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
  apk del --purge \
    build-base \
    bash \
    nano \
    tree \
    ruby-dev \
    git && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

VOLUME [ "/etc/icinga2", "/var/lib/icinga2", "/run/icinga2/cmd" ]

CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
