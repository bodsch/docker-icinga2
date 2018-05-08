
FROM bitnami/minideb:latest as builder

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive

ARG BUILD_DATE
ARG ICINGA2_VERSION
ARG ICINGA2_VCS_REF

RUN \
  echo "export BUILD_DATE=${BUILD_DATE}" > /etc/enviroment && \
  echo "export BUILD_VERSION=${ICINGA2_VERSION}" >> /etc/enviroment && \
  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release) && \
  chsh -s /bin/bash && \
  ln -sf /bin/bash /bin/sh && \
  apt-get update  --quiet --quiet > /dev/null && \
  apt-get dist-upgrade --quiet --quiet > /dev/null && \
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    bzip2 \
    file \
    gnupg2 \
    python3.5-minimal \
    xz-utils \
    > /dev/null && \
  curl \
    --silent \
    https://packages.icinga.com/icinga.key | apt-key add - && \
  echo "deb http://packages.icinga.com/debian icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list && \
  apt-get update --quiet --quiet > /dev/null && \
  ln -s /etc/default /etc/sysconfig && \
  apt-get --quiet --quiet --assume-yes --no-install-recommends install \
    icinga2-bin \
    icinga2-ido-mysql \
    monitoring-plugins \
    > /dev/null && \
  rm -f /etc/apt/sources.list.d/* && \
  apt-get clean --quiet --quiet > /dev/null && \
  echo "" && \
  which icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo ""

WORKDIR /etc/icinga2

CMD ["/bin/bash"]
