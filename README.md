docker-icinga2
==============

Installs an working icinga2 Master or Satellite based on alpine-linux.

This Version includes also an small REST-Service to generate the Certificates for a Satellite via REST Service.

It also include an docker-compose example to create a set of one Master and 2 Satellites with automatich Certificate Exchange.

More then one API User can also be created over one Environment Var.


# Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-icinga2.svg?branch)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-icinga2.svg?branch)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-icinga2.svg?branch)][travis]

[hub]: https://hub.docker.com/r/bodsch/docker-icinga2/
[microbadger]: https://microbadger.com/images/bodsch/docker-icinga2
[travis]: https://travis-ci.org/bodsch/docker-icinga2


# Build

Your can use the included Makefile.

To build the Container: `make build`

To remove the builded Docker Image: `make clean`

Starts the Container: `make run`

Starts the Container with Login Shell: `make shell`

Entering the Container: `make exec`

Stop (but **not kill**): `make stop`

History `make history`

Starts a *docker-compose*: `make compose-up`

Remove the *docker-compose* images: `make compose-down`


# Docker Hub

You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-icinga2/)


# Notices

The actuall Container Supports a stable MySQL Backand to store all needed Datas into it.

The graphite Support are **experimental**.

The dashing Supports create only an API User.

The Cluster and Cert-Service are **experimental**.

## activated Features

- command
- checker
- livestatus
- mainlog
- notification
- graphite (only with API User)


# certificate Service

**EXPERIMENTAL**

[Sourcecode](https://github.com/bodsch/ruby-icinga-cert-service)

### new way (since 2.8)

You can use `expect` on a *satellite* or *agent* to create an certificate request with the *icinga2 node wizard*:

    expect /init/node-wizard.expect

After this, you can use the *cert-service* to sign this request:

    curl \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/sign/${HOSTNAME}


### old way (pre 2.8)

To create a certificate:

    curl \
      --request GET \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --output /tmp/request_${HOSTNAME}.json \
      http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/request/${HOSTNAME}

Download the created certificate:

    curl \
      --request GET \
      --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
      --header "X-CHECKSUM: ${checksum}" \
      --output /tmp/${HOSTNAME}/${HOSTNAME}.tgz \
       http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/cert/${HOSTNAME}

You need a valid and configured API User in Icinga2 and the created Checksum above.

The generated Certificate has an Timeout from 10 Minutes between beginning of creation and download.

You can also look into `rootfs/init/pki_setup.sh`
For Examples to create a Certificate with Commandline Tools look into `rootfs/init/examples/cert-manager.sh`



# supported Environment Vars

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `MYSQL_HOST`                       | -                    | MySQL Host                                                      |
| `MYSQL_PORT`                       | `3306`               | MySQL Port                                                      |
| `MYSQL_ROOT_USER`                  | `root`               | MySQL root User                                                 |
| `MYSQL_ROOT_PASS`                  | *randomly generated* | MySQL root password                                             |
| `IDO_DATABASE_NAME`                | `icinga2core`        | Schema Name for IDO                                             |
| `IDO_PASSWORD`                     | *randomly generated* | MySQL password for IDO                                          |
|                                    |                      |                                                                 |
| `CARBON_HOST`                      | -                    | hostname or IP address where Carbon/Graphite daemon is running  |
| `CARBON_PORT`                      | `2003`               | Carbon port for graphite                                        |
|                                    |                      |                                                                 |
| `ICINGA_MASTER`                    | -                    | The Icinga2-Master FQDN for a Satellite Node                    |
| `ICINGA_PARENT`                    | -                    | The Parent Node for an Cluster Setup                            |
|                                    |                      |                                                                 |
| `BASIC_AUTH_USER`                  | `admin`              | both `BASIC_AUTH_*` and the `ICINGA_MASTER` are importand, if you |
| `BASIC_AUTH_PASS`                  | `admin`              | use and modify the authentication of the *icinga-cert-service*  |
|                                    |                      |                                                                 |
| `ICINGA_API_USERS`                 | -                    | comma separated List to create API Users. The Format are `username:password` |
|                                    |                      | (e.g. `admin:admin,dashing:dashing` and so on)                  |
|                                    |                      |                                                                 |
| `ICINGA_CERT_SERVICE`              | `false`              | enable the Icinga2 Certificate Service                          |
| `ICINGA_CERT_SERVICE_BA_USER`      | `admin`              | The Basic Auth User for the certicate Service                   |
| `ICINGA_CERT_SERVICE_BA_PASSWORD`  | `admin`              | The Basic Auth Password for the certicate Service               |
| `ICINGA_CERT_SERVICE_API_USER`     | -                    | The Certificate Service needs also an API Users                 |
| `ICINGA_CERT_SERVICE_API_PASSWORD` | -                    |                                                                 |
| `ICINGA_CERT_SERVICE_SERVER`       | `localhost`          | Certificate Service Host                                        |
| `ICINGA_CERT_SERVICE_PORT`         | `80`                 | Certificate Service Port                                        |
| `ICINGA_CERT_SERVICE_PATH`         | `/`                  | Certificate Service Path (needful, when they run behind a Proxy |
|                                    |                      |                                                                 |
| `ICINGA_SSMTP_RELAY_SERVER`        | -                    | SMTP Service to send Notifications                              |
| `ICINGA_SSMTP_REWRITE_DOMAIN`      | -                    |                                                                 |
| `ICINGA_SSMTP_RELAY_USE_STARTTLS`  | -                    |                                                                 |
| `ICINGA_SSMTP_SENDER_EMAIL`        | -                    |                                                                 |
| `ICINGA_SSMTP_SMTPAUTH_USER`       | -                    |                                                                 |
| `ICINGA_SSMTP_SMTPAUTH_PASS`       | -                    |                                                                 |
| `ICINGA_SSMTP_ALIASES`             | -                    |                                                                 |
|                                    |                      |                                                                 |
| `DEMO_DATA`                        | `false`              | copy demo data from `/init/demo-data` into `/etc/icinga2` config path |
|                                    |                      |                                                                 |

