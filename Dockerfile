
FROM alpine:3.7

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  BUILD_DATE="2017-12-05" \
  BUILD_TYPE="stable" \
  CERT_SERVICE_VERSION="0.14.4" \
  ICINGA_VERSION="2.8.0-r0"

EXPOSE 5665 4567

LABEL \
  version="1712" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Icinga2 Docker Image" \
  org.label-schema.description="Inofficial Icinga2 Docker Image" \
  org.label-schema.url="https://www.icinga.org/" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-icinga2" \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ICINGA_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="GNU General Public License v3.0"

# ---------------------------------------------------------------------------------------

RUN \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    libffi-dev g++ make git openssl-dev ruby-dev && \
  apk add --quiet --no-cache \
    bash bind-tools curl expect fping inotify-tools icinga2 jq mailx monitoring-plugins mysql-client netcat-openbsd nmap nrpe-plugin openssl pwgen ruby s6 ssmtp unzip && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  cp /usr/lib/nagios/plugins/*     /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /etc/icinga2/automatic-zones.d && \
  mkdir -p /run/icinga2/cmd && \
  chmod u+s /bin/busybox && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /tmp && \
  git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
  cd ruby-icinga-cert-service && \
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${CERT_SERVICE_VERSION}" && \
    git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
  fi && \
  bundle install --quiet && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
  git clone https://github.com/nisabek/icinga2-slack-notifications.git && \
  git clone https://github.com/lazyfrosch/icinga2-telegram.git && \
  apk del --quiet --purge .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  --start-period=10s \
  CMD ps ax | grep -v grep | grep -c "/usr/lib/icinga2/sbin/icinga2" || exit 1

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
