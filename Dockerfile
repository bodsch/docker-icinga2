FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="1.0.0"

ENV TERM xterm

EXPOSE 5665 6666

# ---------------------------------------------------------------------------------------

RUN \
  echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >>  /etc/apk/repositories && \
  apk --quiet update && \
  apk --quiet upgrade && \
  apk --quiet add \
    bash \
    pwgen \
    supervisor \
    fping \
    unzip \
    netcat-openbsd \
    nmap \
    curl \
    bc \
    jq \
    yajl-tools \
    ssmtp \
    mailx \
    mysql-client \
    icinga2@testing \
    monitoring-plugins@testing && \
  rm -rf /var/cache/apk/*

RUN \
  rm -Rf /var/run && \
  ln -s /run /var/run && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  mkdir -p /run/icinga2 /run/icinga2/cmd

RUN \
  chmod u+s /bin/busybox

ADD rootfs/ /

VOLUME  ["/etc/icinga2", "/var/lib/icinga2", "/var/run/icinga2/cmd" ]

# Initialize and run Supervisor
CMD [ "/opt/startup.sh" ]



# ---------------------------------------------------------------------------------------
