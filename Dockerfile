FROM alpine:edge

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.10.0"

#ENV DEBIAN_FRONTEND noninteractive
# ENV TERM xterm

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
    icinga2@testing && \
  rm -rf /var/cache/apk/*

RUN \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/


ADD rootfs/ /

# CMD ['/bin/sh']

RUN chmod u+x /opt/supervisor/*_supervisor

VOLUME  ["/etc/icinga2", "/var/lib/icinga2", "/var/run/icinga2/cmd" ]

# Initialize and run Supervisor
CMD [ "/opt/startup.sh" ]



# ---------------------------------------------------------------------------------------
