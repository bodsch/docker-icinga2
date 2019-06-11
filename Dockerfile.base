ARG BUILD_BASE
# hadolint ignore=DL3006
FROM $BUILD_BASE
# FROM ubuntu:19.04
# FROM debian:9-slim

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION
ARG CERT_SERVICE_TYPE
ARG CERT_SERVICE_VERSION

ENV \
  TERM=xterm \
  DEBIAN_FRONTEND=noninteractive \
  TZ='Europe/Berlin'

# ---------------------------------------------------------------------------------------

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008,DL3014,DL3015,DL4005,SC1091,SC2155
RUN \
  chsh -s /bin/bash && \
  ln -sf /bin/bash /bin/sh && \
  ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  ln -s  /etc/default /etc/sysconfig && \
  apt-get remove \
    --allow-remove-essential \
    --assume-yes \
    --purge \
      e2fsprogs libext2fs2 && \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
      apt-utils && \
  apt-get dist-upgrade \
    --assume-yes && \
  apt-get install \
    --assume-yes \
      ca-certificates \
      curl \
      gnupg > /dev/null && \
  curl \
    --silent \
    https://packages.icinga.com/icinga.key | apt-key add - && \
  . /etc/os-release && \
  if [ "${ID}" = "ubuntu" ]; then \
    if [ -n "${UBUNTU_CODENAME+x}" ]; then \
      DIST="${UBUNTU_CODENAME}"; \
    else \
      DIST="$(lsb_release -c | awk '{print $2}')"; \
    fi \
  elif [ "${ID}" = "debian" ]; then \
    DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release) ;\
  fi && \
  echo " => ${ID} - ${DIST}" && \
  echo "deb http://packages.icinga.com/${ID} icinga-${DIST} main" > "/etc/apt/sources.list.d/${DIST}-icinga.list" && \
  apt-get update && \
  apt-get install \
    --assume-yes \
    --no-install-recommends \
      icinga2-bin \
      icinga2-ido-mysql \
      monitoring-plugins \
      dnsutils \
      file \
      fping \
      inotify-tools \
      jq \
      netcat-openbsd \
      psmisc \
      pwgen \
      python3.5-minimal \
      libtext-english-perl \
      tzdata \
      unzip \
      xz-utils && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /run/icinga2/cmd && \
  mkdir -p /etc/icinga2/zones.d/global-templates && \
  mkdir -p /etc/icinga2/zones.d/director-global && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  apt-get remove \
    --assume-yes \
    --purge \
      gnupg && \
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
  find /var/log -type f -print0 | while IFS= read -r -d '' i; do echo "" > "${i}"; done && \
  echo "" && \
  command -v icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo "" && \
  export ICINGA2_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F '-' '{print $1}' | sed 's|r||') && \
  echo "export BUILD_DATE=${BUILD_DATE}"            > /etc/profile.d/icinga2.sh && \
  echo "export BUILD_VERSION=${BUILD_VERSION}"     >> /etc/profile.d/icinga2.sh && \
  echo "export ICINGA2_VERSION=${ICINGA2_VERSION}" >> /etc/profile.d/icinga2.sh

COPY rootfs/ /
COPY build/check_mem      /usr/lib/nagios/plugins/check_mem
COPY build/check_ssl_cert /usr/lib/nagios/plugins/check_ssl_cert

WORKDIR /etc/icinga2
VOLUME ["/etc/icinga2", "/var/lib/icinga2", "/var/spool/icinga2", "/var/cache/icinga2"]

CMD ["/init/run.sh"]

HEALTHCHECK \
  --interval=30s \
  --timeout=2s \
  --retries=10 \
  --start-period=15s \
  CMD /init/healthcheck.sh

# ---------------------------------------------------------------------------------------
