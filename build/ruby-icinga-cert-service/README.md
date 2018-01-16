icinga-cert-service
===================

The Icinga-Cert-Service is a small service for creating, downloading or signing an Icinga2 certificate.
The service can be used to connect Icinga2 satellites or agents dynamically to an Icinga2 master.

The Cert service is implemented in ruby and offers a simple REST API.

# Status
[![Build Status](https://travis-ci.org/bodsch/ruby-icinga-cert-service.svg)][travis]
[![Dependency Status](https://gemnasium.com/badges/github.com/bodsch/ruby-icinga-cert-service.svg)][gemnasium]

[travis]: https://travis-ci.org/bodsch/ruby-icinga-cert-service
[gemnasium]: https://gemnasium.com/github.com/bodsch/ruby-icinga-cert-service


# Start

To start them run `ruby bin/rest-service.rb`

The following environment variables can be set:

- `ICINGA_HOST`  (default: `nil`)
- `ICINGA_API_PORT` (default: `5665`)
- `ICINGA_API_USER` (default: `root`)
- `ICINGA_API_PASSWORD` (default: `icinga`)
- `REST_SERVICE_PORT` (default: `8080`)
- `REST_SERVICE_BIND` (default: `0.0.0.0`)
- `BASIC_AUTH_USER`  (default: `admin`)
- `BASIC_AUTH_PASS`  (default: `admin`)

The REST-service uses an basic-authentication for the first security step.
The second Step is an configured API user into the Icinga2-Master.
The API user credentials must be set as HTTP-Header vars (see the examples below).

To overwrite the default configuration for the REST-Service, put a `rest-service.yaml` into `/etc` :

```yaml
---
icinga:
  server: master-server
  api:
    port: 5665
    user: root
    password: icinga

rest-service:
  port: 8080
  bind: 192.168.10.10

basic-auth:
  user: ba-user
  password: v2rys3cr3t
```


# Who to used it

## With Icinga2 Version 2.8, we can use the new PKI-Proxy Mode

You can use `expect` on a *satellite* or *agent* to create an certificate request with the *icinga2 node wizard*.
(A complete `expect` example can be found below)

```bash
expect /init/node-wizard.expect
```

After this, you can use the *cert-service* to sign this request:

```bash
curl \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --silent \
  --request GET \
  --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
  --header "X-API-PASSWORD: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
  --write-out "%{http_code}\n" \
  --output /tmp/sign_${HOSTNAME}.json \
  http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/sign/${HOSTNAME}
```

## Otherwise, the pre 2.8 Mode works well

To create a certificate:

```bash
curl \
  --request GET \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --silent \
  --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
  --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
  --output /tmp/request_${HOSTNAME}.json \
  http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/request/${HOSTNAME}
```

this creates an output file, that we use to download the certificate.

## Download the created certificate:

```bash
checksum=$(jq --raw-output .checksum /tmp/request_${HOSTNAME}.json)

curl \
  --request GET \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --silent \
  --header "X-API-USER: ${ICINGA_CERT_SERVICE_API_USER}" \
  --header "X-API-KEY: ${ICINGA_CERT_SERVICE_API_PASSWORD}" \
  --header "X-CHECKSUM: ${checksum}" \
  --output ${WORK_DIR}/pki/${HOSTNAME}/${HOSTNAME}.tgz \
   http://${ICINGA_CERT_SERVICE_SERVER}:${ICINGA_CERT_SERVICE_PORT}/v2/cert/${HOSTNAME}
```

## Create the Satellite `Endpoint`

```bash
cat << EOF > /etc/icinga2/zones.conf

/* the following line specifies that the client connects to the master and not vice versa */
object Endpoint "${master_name}" { host = "${ICINGA_MASTER}"; port = "5665" }
object Zone "master" { endpoints = [ "${master_name}" ] }

object Endpoint NodeName {}
object Zone ZoneName { endpoints = [ NodeName ] ; parent = "master" }

object Zone "global-templates" { global = true }
object Zone "director-global" { global = true }

EOF
```

## NOTE
The generated certificate has an timeout from 10 minutes between beginning of creation and download.


# API

following API Calls are implemented:

## Health Check

The Health Check is important to determine whether the certificate service has started.

```bash
curl \
  --request GET \
  --silent \
  http://${REST-SERVICE}:8080/v2/health-check
```

The health check returns only a string with `healthy` as content.

## Icinga Version

Returns the Icinga Version

```bash
curl \
  --request GET \
  --silent \
  http://${REST-SERVICE}:8080/v2/icinga-version
```

The icinga version call returns only a string with the shortend version as content: `2.8`

## create a certificate request

Create an Certificate request

```bash
curl \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --request GET \
  --header "X-API-USER: cert-service" \
  --header "X-API-KEY: knockknock" \
  http://${REST-SERVICE}:8080/v2/request/${HOST-NAME}
```

## download an certificate

After an certificate request, you can download the created certificate:

```bash
curl \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --request GET \
  --header "X-API-USER: cert-service" \
  --header "X-API-KEY: knockknock" \
  --output /tmp/${HOST-NAME}.tgz \
  http://${REST-SERVICE}:8080/v2/cert/${HOST-NAME}
```

## validate the satellite CA

If the CA has been renewed on the master, all satellites or agents will no longer be able to connect to the master.
To be able to detect this possibility, you can create a checksum of the `ca.crt` file and have it checked by the certificats service.

The following algorithms are supported to create a checksum:
- ´md5`
- ´sha256`
- ´sha384`
- ´sha512`

```bash
checksum=$(sha256sum ${ICINGA_CERT_DIR}/ca.crt | cut -f 1 -d ' ')

curl \
  --request GET \
  http://${REST-SERVICE}:8080/v2/validate/${checksum}
```

## sign a certificate request

Version 2.8 of Icinga2 came with a CA proxy.
Here you can use the well-known `node wizard` to create a certificate request on a satellite or agent.
This certificate only has to be confirmed at the Icinga2 Master.

The certificate files are then replicated to the respective applicant.

With the following API call you can confirm the certificate without being logged on to the master.

```bash
curl \
  --user ${ICINGA_CERT_SERVICE_BA_USER}:${ICINGA_CERT_SERVICE_BA_PASSWORD} \
  --request POST \
  --header "X-API-USER: cert-service" \
  --header "X-API-KEY: knockknock" \
  http://${REST-SERVICE}:8080/v2/sign/${HOST-NAME}
```

The `node wizard` can also be automated (via `expect`):

```

cat << EOF >> ~/node-wizard.expect

#!/usr/bin/expect

# exp_internal 1

log_user 1
set timeout 3

spawn icinga2 node wizard

expect -re "Please specify if this is a satellite/client setup" {
  send -- "y\r"
}
expect -re "Please specify the common name " {
  send -- "[exec hostname -f]\r"
}
expect -re "Master/Satellite Common Name" {
 send -- "$env(ICINGA_MASTER)\r"
}
expect -re "Do you want to establish a connection to the parent node" {
  send -- "y\r"
}
expect -re "endpoint host" {
  send -- "$env(ICINGA_MASTER)\r"
}
expect -re "endpoint port" {
  send -- "5665\r"
}
expect -re "Add more master/satellite endpoints" {
  send -- "n\r"
}
expect -re "Is this information correct" {
  send -- "y\r"
}
expect -re "Please specify the request ticket generated on your Icinga 2 master" {
  send -- "\r"
}
expect -re "Bind Host" {
  send -- "\r"
}
expect -re "Bind Port" {
  send -- "\r"
}
expect -re "config from parent node" {
  send -- "y\r"
}
expect -re "commands from parent node" {
  send -- "y\r"
}

interact

EOF


expect ~/node-wizard.expect 1> /dev/null

```


