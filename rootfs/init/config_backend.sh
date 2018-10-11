
if [[ ! -z "${CONFIG_BACKEND_SERVER}" ]]
then
  if [[ -z "${CONFIG_BACKEND}" ]]
  then
    log_warn "no 'CONFIG_BACKEND' defined"
    return
  fi

  log_info "use '${CONFIG_BACKEND}' as configuration backend"

  if [[ "${CONFIG_BACKEND}" = "consul" ]]
  then
    . /init/config_backend/consul.sh
  elif [[ "${CONFIG_BACKEND}" = "etcd" ]]
  then
    . /init/config_backend/etcd.sh
  else
    log_error "unknown configuration backend '${CONFIG_BACKEND}' defined"
  fi
fi

save_config() {

#  set_var  "root_user" "${MYSQL_SYSTEM_USER}"
#  set_var  "root_password" "${MYSQL_ROOT_PASS}"
#  set_var  "url" ${HOSTNAME}

#  register_node
  set_var  'icinga_version' ${ICINGA2_VERSION}
  set_var  'icinga_cert-service_ba_user'      ${CERT_SERVICE_BA_USER}
  set_var  'icinga_cert-service_ba_password'  ${CERT_SERVICE_BA_PASSWORD}
  set_var  'icinga_cert-service_api_user'     ${CERT_SERVICE_API_USER}
  set_var  'icinga_cert-service_api_password' ${CERT_SERVICE_API_PASSWORD}
  set_var  'icinga_database_ido_user'         'icinga2'
  set_var  'icinga_database_ido_password'     ${IDO_PASSWORD}
  set_var  'icinga_database_ido_schema'       ${IDO_DATABASE_NAME}
  #set_var  'icinga_api_users_'                ''

}
