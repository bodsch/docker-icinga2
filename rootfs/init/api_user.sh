
# create API users
#
create_api_user() {

  local api_file="/etc/icinga2/conf.d/api-users.conf"
  local api_users=

  # the format are following:
  # username:password,username:password, ...
  # for example:
  # ICINGA_API_USERS=root:icinga,dashing:dashing,cert:foo-bar
  #
  [[ -n "${ICINGA_API_USERS}" ]] &&  api_users=$(echo ${ICINGA_API_USERS} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)

  if [[ ! -z "${api_users}" ]]
  then
    log_info "create configuration for API users ..."

    # DESTROY the old entrys
    #
    echo "" > ${api_file}

    for u in ${api_users}
    do
      user=$(echo "${u}" | cut -d: -f1)
      pass=$(echo "${u}" | cut -d: -f2)

      [[ -z ${pass} ]] && pass=${user}

      log_info "      - '${user}'"

      if [[ $(grep -c "object ApiUser \"${user}\"" ${api_file}) -eq 0 ]]
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

create_api_user
