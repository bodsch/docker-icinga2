
FROM alpine:edge

ENV \
  TZ='Europe/Berlin'

ARG BUILD_DATE
ARG BUILD_VERSION
ARG ICINGA2_VERSION

EXPOSE 5665 8080

# ---------------------------------------------------------------------------------------

RUN \
  echo "export BUILD_DATE=${BUILD_DATE}"            > /etc/profile.d/icinga2.sh && \
  echo "export BUILD_VERSION=${BUILD_VERSION}"     >> /etc/profile.d/icinga2.sh && \
  echo "export ICINGA2_VERSION=${ICINGA2_VERSION}" >> /etc/profile.d/icinga2.sh && \
  apk update --quiet --no-cache  && \
  apk upgrade --quiet --no-cache && \
  apk add --quiet --no-cache --virtual .build-deps \
    libffi-dev g++ make git openssl-dev ruby-dev shadow && \
  groupadd -g 1000 icinga && \
  useradd -u 1000 -g icinga -G icinga -d /etc/icinga2 -s /bin/bash icinga && \
  apk add --quiet --no-cache \
    bash bind-tools curl expect fping inotify-tools icinga2 jq mailx monitoring-plugins mariadb-client \
    netcat-openbsd nmap nrpe-plugin openssl pwgen ruby rsync ssmtp tzdata unzip && \
  curl \
    --silent \
    --location \
    --retry 3 \
    --output /usr/bin/vercomp \
  https://gist.githubusercontent.com/bodsch/065b16ea3c3deb83af7f41990d2d273c/raw/6ba6d7b43de7cff78b7eaf3959f4546642b76750/vercomp && \
  chmod +x /usr/bin/vercomp && \
  cp /etc/icinga2/conf.d.example/* /etc/icinga2/conf.d/ && \
  ln -s /usr/lib/nagios/plugins/* /usr/lib/monitoring-plugins/ && \
  /usr/sbin/icinga2 feature enable command checker mainlog notification && \
  mkdir -p /etc/icinga2/objects.d && \
  mkdir -p /run/icinga2/cmd && \
  mkdir -p /etc/icinga2/zones.d/global-templates && \
  mkdir -p /etc/icinga2/zones.d/director-global && \
  cp /etc/icinga2/zones.conf /etc/icinga2/zones.conf-distributed && \
  chmod u+s /bin/busybox && \
  apk del --quiet --purge .build-deps && \
  rm -rf \
    /tmp/* \
    /var/cache/apk/* \
    /root/.gem \
    /root/.bundle && \
  echo "" && \
  which icinga2 && \
  icinga2 --version && \
  icinga2 daemon --validate && \
  icinga2 feature list && \
  echo ""

COPY rootfs/ /

WORKDIR "/etc/icinga2"

VOLUME [ "/etc/icinga2", "/var/lib/icinga2" ]

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  --start-period=10s \
  CMD ps ax | grep -v grep | grep -c $(cat /run/icinga2/icinga2.pid) || exit 1

CMD ["/bin/bash"]
