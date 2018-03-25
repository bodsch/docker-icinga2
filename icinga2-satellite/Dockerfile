
ARG ICINGA2_VERSION
ARG BUILD_DATE
ARG ICINGA2_VCS_REF
ARG CERT_SERVICE_VERSION

FROM bodsch/docker-icinga2:${ICINGA2_VERSION}-source-${ICINGA2_VCS_REF}

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  ICINGA2_TYPE="Satellite" \
  BUILD_DATE=${BUILD_DATE}

EXPOSE 5665

LABEL \
  version="1803" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Icinga2 Docker Image" \
  org.label-schema.description="Inofficial Icinga2 Docker Image" \
  org.label-schema.url="https://www.icinga.org/" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-icinga2" \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ICINGA2_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="GNU General Public License v3.0"

# ---------------------------------------------------------------------------------------

RUN \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache \
    bash bind-tools curl drill expect fping inotify-tools jq mariadb-client netcat-openbsd nrpe-plugin openssl pwgen tzdata unzip && \
  cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
  echo ${TZ} > /etc/timezone && \
  ln -s /usr/lib/nagios/plugins/* /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command checker mainlog && \
  mkdir -p /run/icinga2/cmd && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  chmod u+s /bin/busybox && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  --start-period=10s \
  CMD ps ax | grep -v grep | grep -c "/usr/lib/icinga2/sbin/icinga2" || exit 1

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
