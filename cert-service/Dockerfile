
FROM alpine:3.7

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

ENV \
  TERM=xterm \
  TZ='Europe/Berlin' \
  BUILD_DATE="2018-01-08" \
  BUILD_TYPE="development" \
  CERT_SERVICE_VERSION="0.14.4" \
  ICINGA_VERSION="2.8.0-r0"

EXPOSE 8080

LABEL \
  version="1801" \
  org.label-schema.build-date=${BUILD_DATE}

# ---------------------------------------------------------------------------------------

RUN \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    libffi-dev g++ make git openssl-dev ruby-dev && \
  apk add --quiet --no-cache \
    bash bind-tools curl expect openssl ruby s6 unzip && \
  echo 'gem: --no-document' >> /etc/gemrc && \
  gem install --quiet --no-rdoc --no-ri \
    io-console bundler icinga2 && \
  cd /tmp && \
  git clone https://github.com/bodsch/ruby-icinga-cert-service.git && \
  cd ruby-icinga-cert-service && \
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${CERT_SERVICE_VERSION}" && \
    git checkout tags/${CERT_SERVICE_VERSION} 2> /dev/null ; \
  elif [ "${BUILD_TYPE}" == "development" ] ; then \
    echo "switch to development Branch" && \
    git checkout development 2> /dev/null ; \
  fi && \
  bundle install --quiet && \
  cp -ar /tmp/ruby-icinga-cert-service/bin /usr/local/ && \
  cp -ar /tmp/ruby-icinga-cert-service/lib /usr/local/ && \
  apk del --quiet --purge .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle

COPY rootfs/ /

WORKDIR "/root"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  CMD curl --silent --fail localhost:8080 || exit 1

CMD [ "/init/run.sh" ]

# ---------------------------------------------------------------------------------------
