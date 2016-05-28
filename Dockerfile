
FROM docker-alpine-base:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.1.0"

ENV TERM xterm

EXPOSE 5665 6666

# ---------------------------------------------------------------------------------------

RUN \
  apk --quiet update

RUN \
  apk --quiet add \
    bash \
    pwgen \
    supervisor \
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
    monitoring-plugins

RUN \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  mkdir -p /run/icinga2 /run/icinga2/cmd

RUN \
  chmod u+s /bin/busybox

RUN \
  rm -rf /var/cache/apk/*

ADD rootfs/ /

VOLUME  ["/etc/icinga2", "/var/lib/icinga2", "/var/run/icinga2/cmd" ]

# Initialize and run Supervisor
CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
