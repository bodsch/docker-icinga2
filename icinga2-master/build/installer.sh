#!/bin/sh

. /etc/profile

#echo ""
#env | sort
#echo ""

set -e
set -u
#set -x

if [[ -f /etc/os-release ]]
then
  . /etc/os-release
elif [[ -f /etc/debian_version ]]
then
  ID="debian"
fi

icinga_config_and_version() {

  mkdir -p /run/icinga2/cmd
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed

#  /usr/sbin/icinga2 feature disable command checker mainlog notification
  /usr/sbin/icinga2 feature enable command checker mainlog notification

#  echo ""
#  which icinga2
#  icinga2 --version
#  icinga2 daemon --validate
#  icinga2 feature list
#  echo ""
}

install_cert_service() {

  echo 'gem: --no-document' >> /etc/gemrc

  gem install --quiet --no-rdoc --no-ri \
    io-console bundler etc

  cd /tmp

  if [ "${CERT_SERVICE_TYPE}" = "local" ] ; then
    echo "use local sources"
    ls -1 /build/
    mv /build/ruby-icinga-cert-service /tmp/
  else
    git clone https://github.com/bodsch/ruby-icinga-cert-service.git
    cd ruby-icinga-cert-service
    if [ "${CERT_SERVICE_TYPE}" = "stable" ] ; then
      echo "switch to stable Tag v${CERT_SERVICE_VERSION}"
      git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null
    elif [ "${CERT_SERVICE_TYPE}" = "development" ] ; then
      echo "switch to development Branch"
      git checkout development 2> /dev/null
    fi
  fi

  /tmp/ruby-icinga-cert-service/bin/installer.sh
}

install_vercomp() {

  curl \
    --silent \
    --location \
    --retry 3 \
    --output /usr/bin/vercomp \
  https://gist.githubusercontent.com/bodsch/065b16ea3c3deb83af7f41990d2d273c/raw/6ba6d7b43de7cff78b7eaf3959f4546642b76750/vercomp

  chmod +x /usr/bin/vercomp
}

install_debian() {


  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
  chsh -s /bin/bash
  ln -sf /bin/bash /bin/sh
  ln -sf /sbin/killall5 /sbin/killall
  apt-get update  --quiet --quiet > /dev/null
  apt-get dist-upgrade --quiet --quiet > /dev/null
  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    bzip2 \
    file \
    gnupg2 \
    python3.5-minimal \
    xz-utils \
    > /dev/null

  curl \
    --silent \
    https://packages.icinga.com/icinga.key | apt-key add -
  echo "deb http://packages.icinga.com/debian icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list
  apt-get update --quiet --quiet > /dev/null
  ln -s /etc/default /etc/sysconfig

  apt-get --quiet --quiet --assume-yes --no-install-recommends install \
    icinga2-bin \
    icinga2-ido-mysql \
    monitoring-plugins \
    > /dev/null

  icinga_config_and_version

  #apt-get update --quiet --quiet > /dev/null

  apt-get install --quiet --quiet --assume-yes --no-install-recommends \
    libffi-dev g++ make git libssl-dev ruby-dev \
    bash bind9utils curl dnsutils expect fping inotify-tools jq bsd-mailx mariadb-client \
    netcat-openbsd nagios-nrpe-server openssl pwgen ruby ssmtp tzdata unzip > /dev/null

  install_cert_service
  install_vercomp

  apt-get remove --quiet --quiet --assume-yes --purge \
    libffi-dev gcc make git libssl-dev ruby-dev  > /dev/null

  apt autoremove --assume-yes

  for u in uucp news proxy www-data backup list irc gnats ; do
    userdel $u
  done

  rm -f /etc/apt/sources.list.d/*

  apt-get clean --quiet --quiet > /dev/null

  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /usr/share/doc/* \
    /root/.gem \
    /root/.bundle
}


install_alpine() {

  apk update --quiet --no-cache
  apk upgrade --quiet --no-cache

  apk add --quiet --no-cache --virtual .build-deps \
    curl libffi-dev g++ make git openssl-dev ruby-dev shadow

  repository=$(grep community /etc/apk/repositories)

  ICINGA2_VERSION=$(curl \
  --silent \
  --location \
  --retry 3 \
  ${repository}/x86_64/APKINDEX.tar.gz | \
  gunzip | \
  strings | \
  grep -A1 "P:icinga2" | \
  tail -n1 | \
  cut -d ':' -f2 | \
  cut -d '-' -f1)

  apk add --quiet --no-cache \
    bash bind-tools curl drill expect fping inotify-tools icinga2 jq mailx mariadb-client \
    monitoring-plugins netcat-openbsd nmap nrpe-plugin openssl pwgen ruby ssmtp tzdata unzip

  icinga_config_and_version
  install_vercomp

  cp /usr/share/zoneinfo/${TZ} /etc/localtime
  echo ${TZ} > /etc/timezone

  [[ -e /usr/lib/monitoring-plugins/check_nrpe ]] || ln -s /usr/lib/nagios/plugins/* /usr/lib/monitoring-plugins/

  chmod u+s /bin/busybox

  install_cert_service

  apk del --quiet --purge .build-deps

  rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle
}


if [[ "${ID}" = "debian" ]]
then
  install_debian
elif [[ "${ID}" = "alpine" ]]
then
  install_alpine
else
  echo "unsupported distribution"
  exit 1
fi




echo "export BUILD_DATE=${BUILD_DATE}"            > /etc/profile.d/icinga2.sh
echo "export BUILD_VERSION=${BUILD_VERSION}"     >> /etc/profile.d/icinga2.sh
echo "export ICINGA2_TYPE=${ICINGA2_TYPE}"       >> /etc/profile.d/icinga2.sh
echo "export ICINGA2_VERSION=${ICINGA2_VERSION}" >> /etc/profile.d/icinga2.sh
