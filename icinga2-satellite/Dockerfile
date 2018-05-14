
ARG ICINGA2_VERSION
ARG ICINGA2_VCS_REF

FROM bodsch/docker-icinga2:${ICINGA2_VERSION}-${ICINGA2_VCS_REF}

ARG BUILD_DATE
ARG CERT_SERVICE_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin' \
  BUILD_TYPE="stable" \
  CERT_SERVICE_VERSION="${CERT_SERVICE_VERSION:-0.17.6}" \
  ICINGA2_TYPE="Master"

EXPOSE 5665 8080

LABEL \
  version="1805" \
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
  apt-get update && \
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    bash bind9utils curl dnsutils expect fping inotify-tools jq bsd-mailx mariadb-client \
    netcat-openbsd nagios-nrpe-server openssl pwgen ruby ssmtp tzdata unzip > /dev/null && \
  /usr/sbin/icinga2 feature enable command checker mainlog && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  apt-get clean --quiet --quiet > /dev/null && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/*

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  --start-period=10s \
  CMD ps ax | grep -v grep | grep -c $(cat /run/icinga2/icinga2.pid) || exit 1

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
