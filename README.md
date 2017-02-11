docker-icinga2
==============

Installs an working icinga2 Core or Satellite based on alpine-linux.

This Version includes also an small Cert-Service to generate the Certificates for a Satellite via REST Service.



# Status

[![Build Status](https://travis-ci.org/bodsch/docker-icinga2.svg?branch=1702-02)](https://travis-ci.org/bodsch/docker-icinga2)

# Build

Your can use the included Makefile.

To build the Container: ```make build```

To remove the builded Docker Image: ```make clean```

Starts the Container: ```make run```

Starts the Container with Login Shell: ```make shell```

Entering the Container: ```make exec```

Stop (but **not kill**): ```make stop```

History ```make history```

Starts a *docker-compose*: ```make compose-up```

Remove the *docker-compose* images: ```make compose-down```


# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-icinga2/)


# Notices

The actuall Container Supports a stable MySQL Backand to store all needed Datas into it.

The graphite Support are experimental.

The dashing Supports create only an API User.

The Cluster and Cert-Service are experimental.


# certificate Service

**EXPERIMENTAL**

[Sourcecode](https://github.com/bodsch/ruby-icinga-cert-service)

To create a certificate:

    curl \
      --request GET \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --output /tmp/request_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/request/${HOSTNAME}

Download the created certificate:

    curl \
      --request GET \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --header "X-CHECKSUM: ${checksum}" \
      --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
       http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/cert/${HOSTNAME}

You need a valid and configured API User in Icinga2 and the created Checksum above.

The generated Certificate has an Timeout from 10 Minutes between beginning of creation and download.

You can also look into ```rootfs/usr/local/sbin/icinga2_pki.sh```



# supported Environment Vars

for MySQL Support:

  - MYSQL_HOST  (default: '')
  - MYSQL_PORT  (default: ```3306```)
  - MYSQL_ROOT_USER  (default: ```root```)
  - MYSQL_ROOT_PASS  (default: '')
  - IDO_DATABASE_NAME  (default: ```icinga2core```)
  - IDO_PASSWORD (default: generated with ```$(pwgen -s 15 1)```)

for graphite Support:

  - CARBON_HOST  (default: '')
  - CARBON_PORT  (default: 2003)

for dashing Support:

  - DASHING_API_USER  (optional)
  - DASHING_API_PASS  (optional)

for icinga2 Cluser:

  - ICINGA_CLUSTER (default: ```false```)
  - ICINGA_MASTER  (default: '')

for Icinga2 Cert-Service

  - BASIC_AUTH_USER
  - BASIC_AUTH_PASS
  - ICINGA_CERT_SERVICE (default: ```false```)
  - ICINGA_CERT_SERVICE_BA_USER (default: ```admin```)
  - ICINGA_CERT_SERVICE_BA_PASSWORD (default: ```admin```)
  - ICINGA_CERT_SERVICE_API_USER (default: '')
  - ICINGA_CERT_SERVICE_API_PASSWORD (default: '')
  - ICINGA_CERT_SERVICE_SERVER (default: ```localhost```)
  - ICINGA_CERT_SERVICE_PORT (default: ```80```)
