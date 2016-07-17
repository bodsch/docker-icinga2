#!/bin/sh

# Supported commands:
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

HOSTNAME="$(hostname -s)"

PKI_KEY="/etc/icinga2/pki/${HOSTNAME}.key"
PKI_CSR="/etc/icinga2/pki/${HOSTNAME}.csr"
PKI_CRT="/etc/icinga2/pki/${HOSTNAME}.crt"

ICINGA_MASTER="icinga2-core"

PKI_CMD="icinga2 pki"

# --------------------------------------------------------------------------------------------

chown -R icinga: /var/lib/icinga2

icinga2 api setup
${PKI_CMD} new-cert --cn ${HOSTNAME} --key ${PKI_KEY} --csr ${PKI_CSR}
${PKI_CMD} sign-csr --csr ${PKI_CSR} --cert ${PKI_CRT}

# if [ $(icinga2 feature list | grep Enabled | grep api | wc -l) -eq 0 ]
# then
#   icinga2 feature enable api
# fi

supervisorctl restart icinga2

echo -e "\n\n"


SATELLITES="icinga2-satellite-1 icinga2-satellite-2"

for s in ${SATELLITES}
do
  dir="/tmp/${s}"

  chown icinga: ${dir}

  salt=$(echo ${s} | sha256sum | cut -f 1 -d ' ')

  mkdir ${dir}


  ${PKI_CMD} new-cert --cn ${s} --key ${dir}/${s}.key --csr ${dir}/${s}.csr
  ${PKI_CMD} sign-csr --csr ${dir}/${s}.csr --cert ${dir}/${s}.crt
  ${PKI_CMD} save-cert --key ${dir}/${s}.key --cert ${dir}/${s}.crt --trustedcert ${dir}/trusted-master.crt --host ${ICINGA_MASTER}
  # Receive Ticket from master...
  pki_ticket=$(${PKI_CMD} ticket --cn ${HOSTNAME} --salt ${salt})
  ${PKI_CMD} request --host ${ICINGA_MASTER} --port 5665 --ticket ${pki_ticket} --key ${dir}/${s}.key --cert ${dir}/${s}.crt --trustedcert ${dir}/trusted-master.crt --ca /etc/icinga2/pki/ca.crt

  # openssl x509 -in ${dir}/${s}.crt -text -noout
  # openssl req -in  ${dir}/${s}.csr -noout -text

done

exit 0


#icinga2 pki new-cert --cn ${HOSTNAME} --key /etc/icinga2/pki/${HOSTNAME}.key --cert /etc/icinga2/pki/${HOSTNAME}.crt
#
## Set trusted Cert
#icinga2 pki save-cert --key /etc/icinga2/pki/${HOSTNAME}.key --cert /etc/icinga2/pki/${HOSTNAME}.crt --trustedcert /etc/icinga2/pki/trusted-master.crt --host ${ICINGA_MASTER}
#
#salt=$(echo $(hostname) | sha256sum | cut -f 1 -d ' ')
## Receive Ticket from master...
#pki_ticket=$(icinga2 pki ticket --cn ${HOSTNAME} --salt ${salt})
#echo " [i] PKI Ticket for '${HOSTNAME}' : '${pki_ticket}'"  # =>  delegate_to: "${ICINGA_MASTER}"
#
## Request PKI
#icinga2 pki request --host ${ICINGA_MASTER} --port 5665 --ticket ${pki_ticket} --key /etc/icinga2/pki/${HOSTNAME}.key --cert /etc/icinga2/pki/${HOSTNAME}.crt --trustedcert /etc/icinga2/pki/trusted-master.crt --ca /etc/icinga2/pki/ca.crt
#
## Set Master as Endpoint
#icinga2 node setup --ticket ${pki_ticket} --endpoint ${ICINGA_MASTER} --zone ${HOSTNAME} --master_host ${ICINGA_MASTER} --trustedcert /etc/icinga2/pki/trusted-master.crt



