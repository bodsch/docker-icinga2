FROM debian:jessie

MAINTAINER Bodo Schulz <bodo@boone-schulz.de>

LABEL version="0.9.2"

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

EXPOSE 5665 6666

# ---------------------------------------------------------------------------------------

RUN apt-get -qq update && \
  apt-get -qqy install \
    ca-certificates \
    wget \
    software-properties-common && \
  wget --quiet -O - https://packages.icinga.org/icinga.key | apt-key add - && \
  echo "deb http://packages.icinga.org/debian icinga-jessie-snapshots main" >> /etc/apt/sources.list.d/icinga.list && \
  apt-get -qq update && \
  apt-get -qqy upgrade && \
  apt-get -qqy dist-upgrade && \
  apt-get -qqy install --no-install-recommends \
    fping \
    supervisor \
    pwgen \
    unzip \
    ssmtp \
    mailutils \
    nano \
    netcat \
    nmap \
    mysql-client \
    monitoring-plugins-basic \
    monitoring-plugins-standard \
    icinga2 \
    icinga2-ido-mysql \
    curl \
    bc \
    jq \
    yajl-tools && \
  apt-get clean  && \
  rm -rf /var/lib/apt/lists/*

ADD rootfs/ /

RUN chmod u+x /opt/supervisor/*_supervisor

VOLUME  ["/etc/icinga2", "/var/lib/icinga2", "/var/run/icinga2/cmd" ]

# Initialize and run Supervisor
CMD [ "/opt/startup.sh" ]

# ---------------------------------------------------------------------------------------
