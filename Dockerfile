FROM bodsch/docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.2.3"

ENV TERM xterm

EXPOSE 5665 6666

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet --no-cache update && \
  apk --quiet --no-cache add \
    bash \
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
    monitoring-plugins && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  /usr/sbin/icinga2 feature enable ido-mysql command livestatus compatlog checker mainlog icingastatus && \
  mkdir -p /run/icinga2/cmd && \
  chmod u+s /bin/busybox && \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

VOLUME [ "/etc/icinga2", "/var/lib/icinga2", "/run/icinga2/cmd" ]

CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
