#
# Script to Create API USERS


createAPIUser() {

  local api_file="/etc/icinga2/conf.d/api-users.conf"

  local api_users=

  if [ -n "${ICINGA_API_USERS}" ]
  then
    api_users=$(echo ${ICINGA_API_USERS} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)
  fi

  if [ -z "${api_users}" ]
  then

    echo " [i] no API Users found"
  else

    echo " [i] create configuration for API Users ..."

    # DESTROY the old entrys
    #
    [ -f ${api_file} ] && cat /dev/null > ${api_file}

    for u in ${api_users}
    do

      user=$(echo "${u}" | cut -d: -f1)
      pass=$(echo "${u}" | cut -d: -f2)

      [ -z ${pass} ] && pass=${user}

      echo "      - '${user}'"

      if [ $(grep -c "object ApiUser \"${user}\"" ${api_file}) -eq 0 ]
      then

        cat << EOF >> ${api_file}

object ApiUser "${user}" {
  password    = "${pass}"
  client_cn   = NodeName
  permissions = [ "*" ]
}

EOF
      fi

    done

  fi

}


createAPIUser

# EOF
