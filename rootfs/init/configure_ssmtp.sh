#
#
#

ICINGA_SSMTP_RELAY_SERVER=${ICINGA_SSMTP_RELAY_SERVER:-}
ICINGA_SSMTP_REWRITE_DOMAIN=${ICINGA_SSMTP_REWRITE_DOMAIN:-}
ICINGA_SSMTP_RELAY_USE_STARTTLS=${ICINGA_SSMTP_RELAY_USE_STARTTLS:-}

ICINGA_SSMTP_SENDER_EMAIL=${ICINGA_SSMTP_SENDER_EMAIL:-}
ICINGA_SSMTP_SMTPAUTH_USER=${ICINGA_SSMTP_SMTPAUTH_USER:-}
ICINGA_SSMTP_SMTPAUTH_PASS=${ICINGA_SSMTP_SMTPAUTH_PASS:-}
ICINGA_SSMTP_ALIASES=${ICINGA_SSMTP_ALIASES:-}

#

configureSSMTP() {

  file=/etc/ssmtp/ssmtp.conf

  cat << EOF > ${file}

# ssmtp.conf
# Benutzer, der alle Mails bekommt, die an Benutzer mit einer ID < 1000 adressiert sind.
root=postmaster
# Überschreiben der Absender-Domain.
rewriteDomain=${ICINGA_SSMTP_REWRITE_DOMAIN}
# the mailrelay
mailhub=${ICINGA_SSMTP_RELAY_SERVER}
FromLineOverride=NO
EOF

  if [ "${ICINGA_SSMTP_RELAY_USE_STARTTLS}" = "true" ]
  then

    cat << EOF >> ${file}
UseSTARTTLS=YES
EOF
  fi

  if ( [ ! -z ${ICINGA_SSMTP_SMTPAUTH_USER} ] && [ ! -z ${ICINGA_SSMTP_SMTPAUTH_PASS} ] )
  then

    cat << EOF >> ${file}
AuthUser=${ICINGA_SSMTP_SMTPAUTH_USER}
AuthPass=${ICINGA_SSMTP_SMTPAUTH_PASS}
EOF
  fi


}

createSMTPAliases() {

  file=/etc/ssmtp/revaliases

  [ -f ${file} ] && mv ${file} ${file}-SAVE

  # our default mail-sender
  #
  cat << EOF > ${file}
root:${ICINGA_SSMTP_SENDER_EMAIL}@${ICINGA_SSMTP_REWRITE_DOMAIN}:${ICINGA_SSMTP_RELAY_SERVER}
EOF


  if [ -n "${ICINGA_SSMTP_ALIASES}" ]
  then
    aliases=$(echo ${ICINGA_SSMTP_ALIASES} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)
  fi

  if [ -z "${aliases}" ]
  then

    echo " [i] no SMTP Aliases found"
  else

    # add more aliases
    #
    for u in ${aliases}
    do

      local=$(echo "${u}" | cut -d: -f1)
      email=$(echo "${u}" | cut -d: -f2)

      cat << EOF >> ${file}
${local}:${email}:${ICINGA_SSMTP_RELAY_SERVER}
EOF

    done
  fi

}

configureSSMTP
createSMTPAliases

# EOF
