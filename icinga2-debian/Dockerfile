
FROM bitnami/minideb:latest as builder

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive

ARG BUILD_DATE
ARG ICINGA2_VERSION

RUN \
  echo "export BUILD_DATE=${BUILD_DATE}" > /etc/enviroment && \
  echo "export BUILD_VERSION=${ICINGA2_VERSION}" >> /etc/enviroment && \
  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release) && \
  chsh -s /bin/bash && \
  ln -sf /bin/bash /bin/sh && \
  ln -s  /sbin/killall5 /sbin/killall && \
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
  groupadd -g 1000 icinga && \
  useradd -u 1000 -g icinga -G icinga -d /etc/icinga2 -s /bin/bash icinga && \
  apt-get --quiet --quiet --assume-yes --no-install-recommends install \
    icinga2-bin \
    icinga2-ido-mysql \
    monitoring-plugins \
    > /dev/null && \
  mkdir -p /run/icinga2/cmd && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  /usr/sbin/icinga2 feature disable command checker mainlog notification && \
  rm -f /etc/apt/sources.list.d/* && \
  apt-get clean --quiet --quiet > /dev/null && \
  echo "" && \
  which icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo ""

COPY vercomp /usr/bin/vercomp

WORKDIR /etc/icinga2

CMD ["/bin/bash"]
