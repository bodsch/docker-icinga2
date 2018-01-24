
FROM alpine:3.7

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  BUILD_DATE="2018-01-24" \
  BUILD_TYPE="stable" \
  CERT_SERVICE_VERSION="0.16.5" \
  ICINGA_VERSION="2.8.0-r0"

EXPOSE 5665 8080

LABEL \
  version="1801" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
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
    bash bind-tools curl expect fping inotify-tools icinga2 jq mailx monitoring-plugins mariadb-client netcat-openbsd nmap nrpe-plugin openssl pwgen ruby rsync ssmtp tzdata unzip && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  ln -s /usr/lib/nagios/plugins/* /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /run/icinga2/cmd && \
  mkdir -p /etc/icinga2/zones.d/global-templates && \
  mkdir -p /etc/icinga2/zones.d/director-global && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  chmod u+s /bin/busybox && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler && \
  cd /tmp && \
  if [ "${BUILD_TYPE}" == "local" ] ; then \
    echo "use local sources" && \
    mv /ruby-icinga-cert-service /tmp/ && \
    cd ruby-icinga-cert-service ; \
  else \
    git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
    cd ruby-icinga-cert-service && \
    if [ "${BUILD_TYPE}" == "stable" ] ; then \
      echo "switch to stable Tag v${CERT_SERVICE_VERSION}" && \
      git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
    elif [ "${BUILD_TYPE}" == "development" ] ; then \
      echo "switch to development Branch" && \
      git checkout development 2> /dev/null ; \
    fi \
  fi && \
  bundle install --quiet && \
  gem uninstall --quiet \
    io-console bundler && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
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
