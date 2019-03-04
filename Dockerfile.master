ARG BUILD_IMAGE
# hadolint ignore=DL3006
FROM $BUILD_IMAGE

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION
ARG CERT_SERVICE_TYPE
ARG CERT_SERVICE_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin'

EXPOSE 5665 8080

# ---------------------------------------------------------------------------------------

COPY build/ruby-icinga-cert-service      /tmp/ruby-icinga-cert-service

WORKDIR /tmp

# hadolint ignore=DL3003,DL3008,DL3014
RUN \
  export ICINGA2_TYPE=Master && \
  apt-get install \
    --assume-yes \
    --no-install-recommends  \
      libffi-dev \
      g++ \
      make \
      git \
      libssl-dev \
      ruby-dev \
      bind9utils \
      bsd-mailx \
      mariadb-client \
      nagios-nrpe-server \
      openssl \
      ruby \
      ssmtp && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  bash /tmp/ruby-icinga-cert-service/bin/installer.sh && \
  apt-get remove \
    --assume-yes \
    --purge \
      apt-utils \
      libffi-dev \
      gcc \
      make \
      git \
      gnupg \
      libssl-dev \
      ruby-dev \
      python3-pip && \
  rm -f /etc/apt/sources.list.d/* && \
  apt-get clean && \
  apt autoremove \
    --assume-yes && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.cache \
    /root/.bundle 2> /dev/null && \
  echo "export ICINGA2_TYPE=${ICINGA2_TYPE}"       >> /etc/profile.d/icinga2.sh

WORKDIR /etc/icinga2

# ---------------------------------------------------------------------------------------

LABEL \
  version="${BUILD_VERSION}" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Icinga2 Docker Image" \
  org.label-schema.vcs-ref=${VCS_REF} \
  org.label-schema.description="Inofficial Icinga2 Docker Image" \
  org.label-schema.url="https://www.icinga.org/" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-icinga2" \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ICINGA2_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="GNU General Public License v3.0"

# ---------------------------------------------------------------------------------------
