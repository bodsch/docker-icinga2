#!/bin/sh

# Example Script to create Icinga2 Certificates
#
# This Script is tested in a Docker Container based on Alpine with an installed supervisord!
# For all others distribition, check PATH or start-stop scripts

# ----------------------------------------------------------------------

# Supported commands for pki command:
#   * pki new-ca (sets up a new CA)
#   * pki new-cert (creates a new CSR)
#     Command options:
#       --cn arg                  Common Name
#       --key arg                 Key file path (output
#       --csr arg                 CSR file path (optional, output)
#       --cert arg                Certificate file path (optional, output)
#   * pki request (requests a certificate)
#     Command options:
#       --key arg                 Key file path (input)
#       --cert arg                Certificate file path (input + output)
#       --ca arg                  CA file path (output)
#       --trustedcert arg         Trusted certificate file path (input)
#       --host arg                Icinga 2 host
#       --port arg                Icinga 2 port
#       --ticket arg              Icinga 2 PKI ticket
#   * pki save-cert (saves another Icinga 2 instance's certificate)
#     Command options:
#       --key arg                 Key file path (input), obsolete
#       --cert arg                Certificate file path (input), obsolete
#       --trustedcert arg         Trusted certificate file path (output)
#       --host arg                Icinga 2 host
#       --port arg (=5665)        Icinga 2 port
#   * pki sign-csr (signs a CSR)
#     Command options:
#       --csr arg                 CSR file path (input)
#       --cert arg                Certificate file path (output)
#   * pki ticket (generates a ticket)
#     Command options:
#       --cn arg                  Certificate common name
#       --salt arg                Ticket salt

# ----------------------------------------------------------------------

HOSTNAME="$(hostname -f)"
DOMAINNAME="$(hostname -d)"

PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

ICINGA2_MASTER="icinga2-master"

PKI_CMD="icinga2 pki"

# --------------------------------------------------------------------------------------------

chown -R icinga: /var/lib/icinga2

icinga2 api setup

${PKI_CMD} new-cert \
  --cn ${HOSTNAME} \
  --key ${PKI_KEY} \
  --csr ${PKI_CSR}

${PKI_CMD} sign-csr \
  --csr ${PKI_CSR} \
  --cert ${PKI_CRT}


supervisorctl restart icinga2

echo -e "\n\n"

SATELLITES="icinga2-satellite-1 icinga2-satellite-2"

for s in ${SATELLITES}
do
  dir="/tmp/${s}"

  chown icinga: ${dir}

  salt=$(echo ${s} | sha256sum | cut -f 1 -d ' ')

  mkdir ${dir}


  ${PKI_CMD} new-cert \
    --cn ${s} \
    --key ${dir}/${s}.key \
    --csr ${dir}/${s}.csr

  ${PKI_CMD} sign-csr \
    --csr ${dir}/${s}.csr \
    --cert ${dir}/${s}.crt

  ${PKI_CMD} save-cert \
    --key ${dir}/${s}.key \
    --cert ${dir}/${s}.crt \
    --trustedcert ${dir}/trusted-master.crt \
    --host ${ICINGA2_MASTER}

  # Receive Ticket from master...
  pki_ticket=$(${PKI_CMD} ticket \
    --cn ${HOSTNAME} \
    --salt ${salt})

  ${PKI_CMD} request \
    --host ${ICINGA2_MASTER} \
    --port 5665 \
    --ticket ${pki_ticket} \
    --key ${dir}/${s}.key \
    --cert ${dir}/${s}.crt \
    --trustedcert ${dir}/trusted-master.crt \
    --ca /etc/icinga2/pki/ca.crt

  # openssl x509 -in ${dir}/${s}.crt -text -noout
  # openssl req -in  ${dir}/${s}.csr -noout -text

done

exit 0
