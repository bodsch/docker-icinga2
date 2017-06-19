
FROM alpine:3.6

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  BUILD_DATE="2017-06-19" \
  ICINGA_VERSION="2.6.3-1" \
  APK_ADD="bind-tools build-base ca-certificates curl fping git icinga2 inotify-tools jq mailx monitoring-plugins mysql-client netcat-openbsd nmap nrpe-plugin openssl openssl-dev pwgen ruby ruby-dev ruby-io-console ssmtp supervisor unzip" \
  APK_DEL="build-base git nano ruby-dev"

EXPOSE 5665 6666

LABEL org.label-schema.build-date=${BUILD_DATE} \
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

COPY rootfs/init/Gemfile /

RUN \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \

  apk --quiet --no-cache update && \
  apk --quiet --no-cache upgrade && \
  for apk in ${APK_ADD} ; \
  do \
    apk --quiet --no-cache add ${apk} ; \
  done && \
  gem install --no-rdoc --no-ri --quiet bundle && \
  cd / && \
  bundle update --quiet && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  cp /usr/lib/nagios/plugins/*     /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command livestatus checker mainlog notification && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /etc/icinga2/automatic-zones.d && \
  mkdir -p /run/icinga2/cmd && \
  chmod u+s /bin/busybox && \
  cd /tmp && \
  git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
  for apk in ${APK_DEL} ; \
  do \
    apk del --quiet --purge ${apk} ; \
  done && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/*

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2", "/run/icinga2/cmd" ]

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
