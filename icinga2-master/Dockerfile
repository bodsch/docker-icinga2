
ARG ICINGA2_VERSION
FROM bodsch/docker-icinga2:debian-${ICINGA2_VERSION}

# FROM bitnami/minideb:latest

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION
ARG CERT_SERVICE_TYPE
ARG CERT_SERVICE_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin' \
  ICINGA2_TYPE="Master"

EXPOSE 5665 8080

LABEL \
  version="${BUILD_VERSION}" \
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

COPY build /build

#RUN \
#  /build/installer.sh && \
#  rm -rf /build

RUN \
  echo "export BUILD_DATE=${BUILD_DATE}"            > /etc/profile.d/icinga2.sh && \
  echo "export BUILD_VERSION=${BUILD_VERSION}"     >> /etc/profile.d/icinga2.sh && \
  echo "export ICINGA2_TYPE=Master"                >> /etc/profile.d/icinga2.sh && \
  echo "export ICINGA2_VERSION=${ICINGA2_VERSION}" >> /etc/profile.d/icinga2.sh && \
  apt-get update  --quiet --quiet > /dev/null && \
  apt-get --quiet --quiet --assume-yes --no-install-recommends install \
    libffi-dev g++ make git libssl-dev ruby-dev \
    bind9utils bsd-mailx mariadb-client \
    nagios-nrpe-server openssl ruby ssmtp \
    > /dev/null && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /tmp && \
  echo "install icinga-cert-service" && \
  if [ "${CERT_SERVICE_TYPE}" = "local" ] ; then \
    echo "use local sources" ; \
    mv /build/ruby-icinga-cert-service /tmp/ ; \
  else \
    git clone https://github.com/bodsch/ruby-icinga-cert-service.git ; \
    cd ruby-icinga-cert-service ; \
    if [ "${CERT_SERVICE_TYPE}" = "stable" ] ; then \
      echo "switch to stable Tag v${CERT_SERVICE_VERSION}" ; \
      git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
    elif [ "${CERT_SERVICE_TYPE}" = "development" ] ; then \
      echo "switch to development Branch" ; \
      git checkout development 2> /dev/null ; \
    fi \
  fi && \
  /tmp/ruby-icinga-cert-service/bin/installer.sh && \
  cd / && \
  apt-get remove --quiet --quiet --assume-yes --purge \
    libffi-dev gcc make git libssl-dev ruby-dev  > /dev/null && \
  apt-get clean --quiet --quiet > /dev/null && \
  apt autoremove --assume-yes && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.bundle && \
  echo "" && \
  which icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo ""

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
