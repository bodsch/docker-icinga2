
FROM alpine:latest

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  ALPINE_MIRROR="mirror1.hs-esslingen.de/pub/Mirrors" \
  ALPINE_VERSION="v3.6" \
  TERM=xterm \
  BUILD_DATE="2017-11-08" \
  BUILD_TYPE="stable" \
  CERT_SERVICE_VERSION="0.10.2" \
  ICINGA_VERSION="2.7.1-r1" \
  APK_ADD="bind-tools ca-certificates curl fping g++ git inotify-tools jq libffi-dev make mailx monitoring-plugins mysql-client netcat-openbsd nmap nrpe-plugin openssl openssl-dev pwgen ruby ruby-dev s6 ssmtp unzip bash" \
  APK_DEL="libffi-dev g++ make git openssl-dev ruby-dev" \
  GEMS="io-console bundler"

EXPOSE 5665 4567

LABEL \
  version="1711" \
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
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/main"       > /etc/apk/repositories && \
  echo "http://${ALPINE_MIRROR}/alpine/${ALPINE_VERSION}/community" >> /etc/apk/repositories && \
  apk --no-cache update && \
  apk --no-cache upgrade && \
  apk --no-cache add ${APK_ADD} && \
  #
  apk \
    --no-cache \
    --update-cache \
    --repository http://${ALPINE_MIRROR}/alpine/edge/community \
    --repository http://${ALPINE_MIRROR}/alpine/edge/main \
    --allow-untrusted \
    add icinga2  && \
  #
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --no-rdoc --no-ri ${GEMS} && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  cp /usr/lib/nagios/plugins/*     /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /etc/icinga2/automatic-zones.d && \
  mkdir -p /run/icinga2/cmd && \
  chmod u+s /bin/busybox && \
  cd /tmp && \
  git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
  cd ruby-icinga-cert-service && \
  #
  # build stable packages
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${CERT_SERVICE_VERSION}" && \
    git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
  fi && \
  #
  bundle install && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
  apk del --purge ${APK_DEL} && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
