#!/bin/bash

DIR="/tmp/icinga-pki/xxxxxx"

SATELLITE="icinga2-satellite-2.matrix.lan"
SALT=$(echo ${s} | sha256sum | cut -f 1 -d ' ')

ICINGA2_CERT_DIRECTORY="/etc/icinga2/pki"
ICINGA2_VERSION=$(icinga2 --version | head -n1 | awk -F 'version: ' '{printf $2}' | awk -F \. {'print $1 "." $2'} | sed 's|r||')
[ "${ICINGA2_VERSION}" = "2.8" ] && ICINGA2_CERT_DIRECTORY="/var/lib/icinga2/certs"

[ -d ${DIR} ] && rm -rf ${DIR}
[ -d ${DIR} ] || mkdir -vp ${DIR}

chown icinga: ${DIR}

icinga2 pki new-cert \
  --cn ${SATELLITE} \
  --key ${DIR}/${SATELLITE}.key \
  --csr ${DIR}/${SATELLITE}.csr

icinga2 pki sign-csr \
  --csr ${DIR}/${SATELLITE}.csr \
  --cert ${DIR}/${SATELLITE}.crt

icinga2 pki save-cert \
  --key ${DIR}/${SATELLITE}.key \
  --cert ${DIR}/${SATELLITE}.crt \
  --trustedcert ${DIR}/trusted-master.crt \
  --host icinga2-master.matrix.lan

ticket=$(icinga2 pki ticket \
  --cn icinga2-master.matrix.lan \
  --salt ${SALT})

icinga2 pki request \
  --host icinga2-master.matrix.lan \
  --port 5665 \
  --ticket ${ticket} \
  --key ${DIR}/${SATELLITE}.key \
  --cert ${DIR}/${SATELLITE}.crt \
  --trustedcert ${DIR}/trusted-master.crt \
  --ca ${ICINGA2_CERT_DIRECTORY}/ca.crt

