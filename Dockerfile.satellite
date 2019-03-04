ARG BUILD_IMAGE
# hadolint ignore=DL3006
FROM $BUILD_IMAGE

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin'

EXPOSE 5665

# ---------------------------------------------------------------------------------------

RUN \
  export ICINGA2_TYPE=Satellite && \
  export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 && \
  apt-get remove \
    --assume-yes \
    --purge \
      apt-utils \
      libffi-dev \
      gcc \
      make \
      git \
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
