
ARG ICINGA2_VERSION
FROM bodsch/docker-icinga2:${ICINGA2_VERSION}-debian

# FROM bitnami/minideb:latest

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION
ARG CERT_SERVICE_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin' \
  CERT_SERVICE_TYPE="stable" \
  CERT_SERVICE_VERSION="${CERT_SERVICE_VERSION:-0.17.6}" \
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

RUN \
  # echo "export ICINGA2_TYPE=Master" >> /etc/profile.d/icinga2.sh && \
  #
  /build/installer.sh && \
  rm -rf /build

#  apt-get update --quiet --quiet > /dev/null && \
#  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
#    libffi-dev g++ make git libssl-dev ruby-dev \
#    bash bind9utils curl dnsutils expect fping inotify-tools jq bsd-mailx mariadb-client \
#    netcat-openbsd nagios-nrpe-server openssl pwgen ruby ssmtp tzdata unzip > /dev/null && \
#  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
#  echo 'gem: --no-document' >> /etc/gemrc && \
#  gem install --quiet --no-rdoc --no-ri \
#    io-console bundler && \
#  cd /tmp && \
#  if [ "${BUILD_TYPE}" = "local" ] ; then \
#    echo "use local sources" && \
#    ls -1 /build/ && \
#    mv /build/ruby-icinga-cert-service /tmp/ ; \
#  else \
#    git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
#    cd ruby-icinga-cert-service && \
#    if [ "${BUILD_TYPE}" = "stable" ] ; then \
#      echo "switch to stable Tag v${CERT_SERVICE_VERSION}" && \
#      git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
#    elif [ "${BUILD_TYPE}" = "development" ] ; then \
#      echo "switch to development Branch" && \
#      git checkout development 2> /dev/null ; \
#    fi \
#  fi && \
#  /tmp/ruby-icinga-cert-service/bin/installer.sh && \
#  apt-get remove --quiet --quiet --assume-yes --purge \
#    libffi-dev gcc make git libssl-dev ruby-dev  > /dev/null && \
#  apt autoremove --assume-yes && \
#  for u in uucp news proxy www-data backup list irc gnats ; do \
#    userdel $u; \
#  done && \
#  apt-get clean --quiet --quiet > /dev/null && \
#  rm -rf \
#    /tmp/* \
#    /var/cache/debconf/* \
#    /usr/share/doc/* \
#    /root/.gem \
#    /root/.bundle

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
