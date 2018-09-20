
# docker-icinga2

creates several containers with different icinga2 characteristics:

- [icinga2](./build-from-source) created from the sourcecode (alpine based)
- [icinga2](./icinga2-debian) debain based icinga2 installation
- icinga2 as [master](./icinga2-master) with a certificats service
- icinga2 [satellite](./icinga2-satellite)

---

# Status

[![Docker Pulls](https://img.shields.io/docker/pulls/bodsch/docker-icinga2.svg?branch)][hub]
[![Image Size](https://images.microbadger.com/badges/image/bodsch/docker-icinga2.svg?branch)][microbadger]
[![Build Status](https://travis-ci.org/bodsch/docker-icinga2.svg?branch)][travis]

[hub]: https://hub.docker.com/r/bodsch/docker-icinga2/
[microbadger]: https://microbadger.com/images/bodsch/docker-icinga2
[travis]: https://travis-ci.org/bodsch/docker-icinga2


# Build
You can use the included Makefile.

- To build the Container: `make`
- To remove the builded Docker Image: `make clean`
- Starts the Container: `make run`
- Starts the Container with Login Shell: `make shell`
- Entering the Container: `make exec`
- Stop (but **not kill**): `make stop`
- History `make history`

_You can specify an image version by using the `ICINGA2_VERSION` environment variable (This defaults to the "latest" tag)._

_To change this export an other value for `ICINGA2_VERSION` (e.g. `export ICINGA_VERSION=2.8.4`)_


# Contribution
Please read [Contribution](CONTRIBUTIONG.md)

# Development,  Branches (Github Tags)
The `master` Branch is my *Working Horse* includes the "latest, hot shit" and can be complete broken!

If you want to use something stable, please use a [Tagged Version](https://github.com/bodsch/docker-icinga2/tags) or an [Branch](https://github.com/bodsch/docker-icinga2/branches) like `1712` or `1801`

# side-channel / custom scripts
if use need some enhancements, you can add some (bash) scripts and add them via volume to the container:

```bash
--volume=/${PWD}/tmp/test.sh:/init/custom.d/test.sh
```

***This scripts will be started before everything else!***

***YOU SHOULD KNOW WHAT YOU'RE DOING.***

***THIS CAN BREAK THE COMPLETE ICINGA2 CONFIGURATION!***


# Availability

I use the official [Icinga2 packages](https://pkgs.alpinelinux.org/packages?name=icinga2&branch=&repo=&arch=&maintainer=) from Apline.

If one of them is removed, please contact Alpine and don't complain here!

I remove branches as soon as they are disfunctional (e. g. if a package is no longer available at Alpine). Not immediately, but certainly after 2 months.


# Docker Hub
You can find the Container also at  [DockerHub](https://hub.docker.com/r/bodsch/docker-icinga2/)


# Notices
The actuall Container Supports a stable MySQL Backand to store all needed Datas into it.

the graphite feature is **experimentally** and not conclusively tested.


## activated Icinga2 Features

- command
- checker
- mainlog
- notification
- graphite (only available if the environment variables are set)


# certificate service (**EXPERIMENTAL**)

[Sourcecode](https://github.com/bodsch/ruby-icinga-cert-service)

To connect a satellite to a master you need a certificate, which is issued by the master and signed by its CA.

The Icinga2 documentation provides more information about [Distributed Monitoring and Certificates](https://github.com/Icinga/icinga2/blob/master/doc/06-distributed-monitoring.md#signing-certificates-on-the-master-).

**I strongly recommend a study of the documentation!**

Within a docker environment this is a bit more difficult, so an external service is used to simplify this.
This service is constantly being developed further, but is integrated into the docker container in a stable version.

**The certificate service is only available at an Icinga2 Master!**

## usage

Certificate exchange is automated within the docker containers.
If you want to issue your own certificate, you can use the following API calls.

**You need a valid and configured API User in Icinga2.**

The certificate service requires the following environment variables:

- `ICINGA2_MASTER` (default: ``)
- `BASIC_AUTH_USER` (default: `admin`)
- `BASIC_AUTH_PASS` (default: `admin`)
- `ICINGA2_API_PORT` (default: `5665`)
- `ICINGA2_API_USER` (default: `root`)
- `ICINGA2_API_PASSWORD` (default: `icinga`)


### new way (since Icinga2 2.8)

You can use `expect` on a *satellite* or *agent* to create an certificate request with the *icinga2 node wizard*:

    expect /init/node-wizard.expect

After this, you can use the *cert-service* to sign this request:

    curl \
      --user ${ICINGA2_CERT_SERVICE_BA_USER}:${ICINGA2_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --request GET \
      --header "X-API-USER: ${ICINGA2_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA2_CERT_SERVICE_API_PASSWORD}" \
      --write-out "%{http_code}\n" \
      --output /tmp/sign_${HOSTNAME}.json \
      http://${ICINGA2_CERT_SERVICE_SERVER}:${ICINGA2_CERT_SERVICE_PORT}/v2/sign/${HOSTNAME}

After a restart of the Icinga2 Master the certificate is active and a secure connection can be established.


### old way (pre Icinga2 2.8)

To create a certificate:

    curl \
      --request GET \
      --user ${ICINGA2_CERT_SERVICE_BA_USER}:${ICINGA2_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA2_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA2_CERT_SERVICE_API_PASSWORD}" \
      --output /tmp/request_${HOSTNAME}.json \
      http://${ICINGA2_CERT_SERVICE_SERVER}:${ICINGA2_CERT_SERVICE_PORT}/v2/request/${HOSTNAME}

Extract the session checksum from the request above.

    checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

Download the created certificate:

    curl \
      --request GET \
      --user ${ICINGA2_CERT_SERVICE_BA_USER}:${ICINGA2_CERT_SERVICE_BA_PASSWORD} \
      --silent \
      --header "X-API-USER: ${ICINGA2_CERT_SERVICE_API_USER}" \
      --header "X-API-PASSWORD: ${ICINGA2_CERT_SERVICE_API_PASSWORD}" \
      --header "X-CHECKSUM: ${checksum}" \
      --output /tmp/${HOSTNAME}/${HOSTNAME}.tgz \
       http://${ICINGA2_CERT_SERVICE_SERVER}:${ICINGA2_CERT_SERVICE_PORT}/v2/cert/${HOSTNAME}


**The generated certificate has an timeout from 10 minutes between beginning of creation and download.**

You can also look into `rootfs/init/examples/use_cert-service.sh`

For Examples to create a certificate with commandline tools look into `rootfs/init/examples/cert-manager.sh`


# supported Environment Vars

**make sure you only use the environment variable you need!**

## icinga2

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA2_LOGLEVEL`                 | `warning`            | The minimum severity for the main-log.<br>For more information, see into the [icinga doku](https://www.icinga.com/docs/icinga2/latest/doc/09-object-types/#objecttype-filelogger) |

## database support

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `MYSQL_HOST`                       | -                    | MySQL Host                                                      |
| `MYSQL_PORT`                       | `3306`               | MySQL Port                                                      |
| `MYSQL_ROOT_USER`                  | `root`               | MySQL root User                                                 |
| `MYSQL_ROOT_PASS`                  | *randomly generated* | MySQL root password                                             |
| `IDO_DATABASE_NAME`                | `icinga2core`        | Schema Name for IDO                                             |
| `IDO_PASSWORD`                     | *randomly generated* | MySQL password for IDO                                          |

## create API User

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA2_API_USERS`                | -                    | comma separated List to create API Users.<br>The Format are `username:password`<br>(e.g. `admin:admin,dashing:dashing` and so on)                  |

## support Carbon/Graphite

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
|                                    |                      |                                                                 |
| `CARBON_HOST`                      | -                    | hostname or IP address where Carbon/Graphite daemon is running  |
| `CARBON_PORT`                      | `2003`               | Carbon port for graphite                                        |

## support the Icinga Cert-Service

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA2_MASTER`                   | -                    | The Icinga2-Master FQDN for a Satellite Node                    |
| `ICINGA2_PARENT`                   | -                    | The Parent Node for an Cluster Setup                            |
|                                    |                      |                                                                 |
| `BASIC_AUTH_USER`                  | `admin`              | both `BASIC_AUTH_*` and the `ICINGA2_MASTER` are importand, if you |
| `BASIC_AUTH_PASS`                  | `admin`              | use and modify the authentication of the *icinga-cert-service*  |
|                                    |                      |                                                                 |
| `CERT_SERVICE_BA_USER`             | `admin`              | The Basic Auth User for the certicate Service                   |
| `CERT_SERVICE_BA_PASSWORD`         | `admin`              | The Basic Auth Password for the certicate Service               |
| `CERT_SERVICE_API_USER`            | -                    | The Certificate Service needs also an API Users                 |
| `CERT_SERVICE_API_PASSWORD`        | -                    |                                                                 |
| `CERT_SERVICE_SERVER`              | `localhost`          | Certificate Service Host                                        |
| `CERT_SERVICE_PORT`                | `80`                 | Certificate Service Port                                        |
| `CERT_SERVICE_PATH`                | `/`                  | Certificate Service Path (needful, when they run behind a Proxy |

## notifications over SMTP

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `ICINGA2_SSMTP_RELAY_SERVER`       | -                    | SMTP Service to send Notifications                              |
| `ICINGA2_SSMTP_REWRITE_DOMAIN`     | -                    |                                                                 |
| `ICINGA2_SSMTP_RELAY_USE_STARTTLS` | -                    |                                                                 |
| `ICINGA2_SSMTP_SENDER_EMAIL`       | -                    |                                                                 |
| `ICINGA2_SSMTP_SMTPAUTH_USER`      | -                    |                                                                 |
| `ICINGA2_SSMTP_SMTPAUTH_PASS`      | -                    |                                                                 |
| `ICINGA2_SSMTP_ALIASES`            | -                    |                                                                 |

## activate some Demodata (taken from the official Icinga-Vagrant repository)

| Environmental Variable             | Default Value        | Description                                                     |
| :--------------------------------- | :-------------       | :-----------                                                    |
| `DEMO_DATA`                        | `false`              | copy demo data from `/init/demo-data` into `/etc/icinga2` config path |



# Icinga2 Master and Satellite

To connect a satellite to a master, the master must have activated the Cert service and the satellite must know how
to reach it.

A docker-compose file can be created with `make compose-file` and look like this::

```bash
networks:
  backend: {}
  database: {}
  frontend: {}
  satellite: {}
services:
  database:
    container_name: database
    environment:
      MYSQL_ROOT_PASS: vYUQ14SGVrJRi69PsujC
      MYSQL_SYSTEM_USER: root
    hostname: database
    image: bodsch/docker-mysql:latest
    networks:
      backend: null
      database: null
    volumes:
    - /etc/localtime:/etc/localtime:ro
  icinga2-master:
    build:
      args:
        BUILD_DATE: '2018-08-25'
        BUILD_VERSION: '1808'
        CERT_SERVICE_TYPE: stable
        CERT_SERVICE_VERSION: 0.18.3
        ICINGA2_VERSION: 2.9.1
      context: /src/docker/docker-icinga2
      dockerfile: Dockerfile.master
    container_name: icinga2-master
    environment:
      BASIC_AUTH_PASS: admin
      BASIC_AUTH_USER: admin
      CARBON_HOST: ''
      CARBON_PORT: '2003'
      CERT_SERVICE_API_PASSWORD: icinga
      CERT_SERVICE_API_USER: root
      CERT_SERVICE_BA_PASSWORD: admin
      CERT_SERVICE_BA_USER: admin
      CERT_SERVICE_PATH: /cert-service/
      CERT_SERVICE_PORT: '443'
      CERT_SERVICE_SERVER: nginx
      DEBUG: '0'
      DEMO_DATA: "false"
      ICINGA2_API_USERS: root:icinga,dashing:dashing,cert:foo-bar
      ICINGA2_MASTER: icinga2-master.matrix.lan
      IDO_PASSWORD: qUVuLTk9oEDUV0A
      LOG_LEVEL: INFO
      MYSQL_HOST: database
      MYSQL_ROOT_PASS: vYUQ14SGVrJRi69PsujC
      MYSQL_ROOT_USER: root
    hostname: icinga2-master.matrix.lan
    links:
    - database
    networks:
      backend: null
      database: null
    ports:
    - published: 5665
      target: 5665
    - published: 8080
      target: 8080
    privileged: false
    restart: always
    volumes:
    - /etc/localtime:/etc/localtime:ro
  icinga2-satellite-1:
    build:
      args:
        BUILD_DATE: '2018-08-25'
        BUILD_VERSION: '1808'
        ICINGA2_VERSION: 2.9.1
      context: /src/docker/docker-icinga2
      dockerfile: Dockerfile.satellite
    container_name: icinga2-satellite-1
    environment:
      CERT_SERVICE_API_PASSWORD: icinga
      CERT_SERVICE_API_USER: root
      CERT_SERVICE_BA_PASSWORD: admin
      CERT_SERVICE_BA_USER: admin
      CERT_SERVICE_PATH: /cert-service/
      CERT_SERVICE_PORT: '443'
      CERT_SERVICE_SERVER: nginx
      DEBUG: '0'
      ICINGA2_MASTER: icinga2-master.matrix.lan
      ICINGA2_PARENT: icinga2-master.matrix.lan
    hostname: icinga2-satellite-1.matrix.lan
    links:
    - icinga2-master:icinga2-master.matrix.lan
    networks:
      backend: null
      satellite: null
    privileged: true
    restart: always
    volumes:
    - /dev:/dev:ro
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /sys:/sys:ro
  icinga2-satellite-2:
    build:
      args:
        BUILD_DATE: '2018-08-25'
        BUILD_VERSION: '1808'
        ICINGA2_VERSION: 2.9.1
      context: /src/docker/docker-icinga2
      dockerfile: Dockerfile.satellite
    container_name: icinga2-satellite-2
    environment:
      CERT_SERVICE_API_PASSWORD: icinga
      CERT_SERVICE_API_USER: root
      CERT_SERVICE_BA_PASSWORD: admin
      CERT_SERVICE_BA_USER: admin
      CERT_SERVICE_PATH: /cert-service/
      CERT_SERVICE_PORT: '443'
      CERT_SERVICE_SERVER: nginx
      DEBUG: '0'
      ICINGA2_MASTER: icinga2-master.matrix.lan
      ICINGA2_PARENT: icinga2-master.matrix.lan
    hostname: icinga2-satellite-2.matrix.lan
    links:
    - icinga2-master:icinga2-master.matrix.lan
    networks:
      backend: null
      satellite: null
    privileged: true
    restart: always
    volumes:
    - /dev:/dev:ro
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /src/docker/docker-icinga2/import:/import:ro
    - /sys:/sys:ro
  icingaweb2:
    container_name: icingaweb2
    environment:
      ICINGA2_CMD_API_PASS: icinga
      ICINGA2_CMD_API_USER: root
      ICINGA2_MASTER: icinga2-master.matrix.lan
      ICINGAWEB2_USERS: icinga:icinga,foo:bar
      ICINGAWEB_DIRECTOR: "false"
      IDO_DATABASE_NAME: icinga2core
      IDO_PASSWORD: qUVuLTk9oEDUV0A
      MYSQL_HOST: database
      MYSQL_ROOT_PASS: vYUQ14SGVrJRi69PsujC
      MYSQL_ROOT_USER: root
    hostname: icingaweb2.matrix.lan
    image: bodsch/docker-icingaweb2:2.6.1
    links:
    - database
    - icinga2-master:icinga2-master.matrix.lan
    networks:
      backend: null
      database: null
      frontend: null
    ports:
    - target: 80
  nginx:
    container_name: nginx
    depends_on:
    - icinga2-master
    - icingaweb2
    hostname: nginx
    image: bodsch/docker-nginx:1.14.0
    links:
    - icinga2-master
    - icingaweb2:icingaweb2.matrix.lan
    networks:
      backend: null
      frontend: null
    ports:
    - published: 80
      target: 80
    - published: 443
      target: 443
    restart: always
    volumes:
    - /src/docker/docker-icinga2/compose/config/nginx.conf:/etc/nginx/nginx.conf:ro
    - /src/docker/docker-icinga2/compose/ssl/cert.pem:/etc/nginx/secure/localhost/cert.pem:ro
    - /src/docker/docker-icinga2/compose/ssl/dh.pem:/etc/nginx/secure/localhost/dh.pem:ro
    - /src/docker/docker-icinga2/compose/ssl/key.pem:/etc/nginx/secure/localhost/key.pem:ro
version: '3.3'
```

## ssl certificate

In the above example the nginx is started with SSL support.

You can create the required certificate locally as follows.

At the following prompt, the most important line is the one requesting the **common name**.

Here you have to enter the domain name which is assigned to the respective computer (`hostname -f` or `localhost`).


```bash
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/key.pem -out ssl/cert.pem

Generating a 2048 bit RSA private key
.....+++
..........................................+++
writing new private key to 'ssl/key.pem'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:DE
State or Province Name (full name) [Some-State]:Hamburg
Locality Name (eg, city) []:Hamburg
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:localhost
Email Address []:
```

Then we create a Diffie-Hellman group to activate *Perfect Forward Secrecy*:

```bash
$ openssl dhparam -out ssl/dh.pem 2048
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
....................................
```

The 3 files created then belong in the directory `compose/ssl`.



In this example I use my own docker containers:

- [database](https://hub.docker.com/r/bodsch/docker-mysql/builds/)
- [Icinga2](https://hub.docker.com/r/bodsch/docker-icinga2/builds/)
- [Icinga Web2](https://hub.docker.com/r/bodsch/docker-icingaweb2/builds/)

Please check for deviating tags at Docker Hub!

This example can be used as follows: `docker-compose up --build`

Afterwards you can see Icinga Web2 in your local browser at [http://localhost](http://localhost).

![master-satellite](doc/assets/master-satellite.jpg)



