#!/bin/bash

set -u
set -e
# set -x

CERT_SERVICE_TYPE=${CERT_SERVICE_TYPE:-stable}
CERT_SERVICE_VERSION=${CERT_SERVICE_VERSION:-0.18.2}

export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

init() {

  chsh -s /bin/bash
  ln -sf /bin/bash /bin/sh
  ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
  ln -s  /etc/default /etc/sysconfig
}

vercomp() {

  curl \
    --silent \
    --location \
    --retry 3 \
    --output /usr/bin/vercomp \
  https://gist.githubusercontent.com/bodsch/065b16ea3c3deb83af7f41990d2d273c/raw/6ba6d7b43de7cff78b7eaf3959f4546642b76750/vercomp && \
  chmod +x /usr/bin/vercomp
}

install_apt_update() {

  apt-get update
  apt-get install \
    --assume-yes \
    --no-install-recommends \
      apt-utils
  apt-get dist-upgrade \
    --assume-yes
  apt-get install \
    --assume-yes \
      ca-certificates \
      curl \
      gnupg > /dev/null
}

install_icinga2() {

  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)

  curl \
    --silent \
    https://packages.icinga.com/icinga.key | apt-key add -

  echo "deb http://packages.icinga.com/debian icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list

  apt-get update

  apt-get install \
    --assume-yes \
    --no-install-recommends \
      icinga2-bin \
      icinga2-ido-mysql \
      monitoring-plugins \
      dnsutils \
      expect \
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
      xz-utils

  mkdir -p /etc/icinga2/objects.d
  mkdir -p /run/icinga2/cmd
  mkdir -p /etc/icinga2/zones.d/global-templates
  mkdir -p /etc/icinga2/zones.d/director-global
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed

  cp /build/check_mem /usr/lib/nagios/plugins/check_mem
  cp /build/check_ssl_cert /usr/lib/nagios/plugins/check_ssl_cert
}

install_tools() {

  apt-get install \
    --assume-yes \
      python3-pip \
      git

#  cd /tmp
#  git clone https://github.com/taladar/http-observatory-cli
#
#  cd http-observatory-cli
#
#  pip3 install --quiet --requirement requirements.txt
#  python3 -W ignore::UserWarning:distutils.dist setup.py install --quiet > /dev/null
#
#  cd ~

  pip3 install httpobs-cli --quiet > /dev/null
}

install_tools_for_master() {

  apt-get install \
    --assume-yes \
    --no-install-recommends  \
      libffi-dev g++ make git libssl-dev ruby-dev \
      bind9utils bsd-mailx mariadb-client \
      nagios-nrpe-server openssl ruby ssmtp
}

install_icinga_cert_service() {

  cd /tmp

  echo 'gem: --no-document' >> /etc/gemrc
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler

  echo "install icinga-cert-service"
  if [[ "${CERT_SERVICE_TYPE}" = "local" ]]
  then
    echo "use local sources"
    mv /build/ruby-icinga-cert-service /tmp/
  else
    git clone https://github.com/bodsch/ruby-icinga-cert-service.git
    cd ruby-icinga-cert-service
    if [[ "${CERT_SERVICE_TYPE}" = "stable" ]]
    then
      echo "switch to stable Tag v${CERT_SERVICE_VERSION}"
      git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null
    elif [[ "${CERT_SERVICE_TYPE}" = "development" ]]
    then
      echo "switch to development Branch"
      git checkout development 2> /dev/null
    fi
  fi

  /tmp/ruby-icinga-cert-service/bin/installer.sh

  cd ~
}

cleanup() {

  apt-get remove \
    --assume-yes \
    --purge \
      apt-utils libffi-dev gcc make git libssl-dev ruby-dev python3-pip git

  rm -f /etc/apt/sources.list.d/*
  apt-get clean
  apt autoremove \
    --assume-yes

  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.cache \
    /root/.bundle 2> /dev/null
}

info() {

  echo ""
  which icinga2
  icinga2 --version
  icinga2 daemon --validate
  icinga2 feature list
  echo ""

  export ICINGA2_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F '-' '{print $1}' | sed 's|r||')
}

# --------------------------------------------------------------------------------------

init
install_apt_update
vercomp
install_icinga2
# install_tools

if [[ $ICINGA2_TYPE == "Master" ]]
then
  install_tools_for_master
  install_icinga_cert_service
fi

cleanup
info

echo "export BUILD_DATE=${BUILD_DATE}"            > /etc/profile.d/icinga2.sh
echo "export BUILD_VERSION=${BUILD_VERSION}"     >> /etc/profile.d/icinga2.sh
echo "export ICINGA2_VERSION=${ICINGA2_VERSION}" >> /etc/profile.d/icinga2.sh
echo "export ICINGA2_TYPE=${ICINGA2_TYPE}"       >> /etc/profile.d/icinga2.sh
