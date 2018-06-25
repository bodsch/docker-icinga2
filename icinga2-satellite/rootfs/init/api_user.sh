
# create API users
#
create_api_user() {

  local api_file="/etc/icinga2/conf.d/api-users.conf"
  local api_users=

  [[ -z "${ICINGA2_API_USERS}" ]] && return

  # the format are following:
  # username:password,username:password, ...
  # for example:
  # ICINGA2_API_USERS=root:icinga,dashing:dashing,cert:foo-bar
  #
  [[ -n "${ICINGA2_API_USERS}" ]] &&  api_users=$(echo ${ICINGA2_API_USERS} | sed -e 's/,/ /g' -e 's/\s+/\n/g' | uniq)

  if [[ ! -z "${api_users}" ]]
  then

    if [[ $(cat ${api_file} | wc -l) -eq 6 ]]
    then
      log_info "create configuration for API users ..."

      # the initial configuration
      # make it blank and create our default users
      #
      echo "" > ${api_file}

      for u in ${api_users}
      do
        user=$(echo "${u}" | cut -d: -f1)
        pass=$(echo "${u}" | cut -d: -f2)

        [[ -z ${pass} ]] && pass=${user}

        if [[ $(grep -c "object ApiUser \"${user}\"" ${api_file}) -eq 0 ]]
        then
          log_info "  add user '${user}'"

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
  fi

}

create_api_user
