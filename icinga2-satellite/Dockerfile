
FROM bodsch/docker-icinga2:2.8.1-source-r1

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  BUILD_DATE="2018-02-05" \
  CERT_SERVICE_VERSION="0.17.5" \
  ICINGA2_TYPE="Satellite"

EXPOSE 5665

LABEL \
  version="1802" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Icinga2 Docker Image" \
  org.label-schema.description="Inofficial Icinga2 Docker Image" \
  org.label-schema.url="https://www.icinga.org/" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-icinga2" \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ICINGA_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="GNU General Public License v3.0"

# ---------------------------------------------------------------------------------------

#ADD build/ /build/

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
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle

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
