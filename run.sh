#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

DATABASE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-mysql)
GRAPHITE_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${USER}-graphite)

[ -z ${DATABASE_IP} ] && { echo "No Database Container '${USER}-mysql' running!"; exit 1; }
[ -z ${GRAPHITE_IP} ] && { echo "No Graphite Container '${USER}-graphite' running!"; exit 1; }

DOCKER_DBA_ROOT_PASS=${DOCKER_DBA_ROOT_PASS:-foo.bar.Z}
DOCKER_IDO_PASS=${DOCKER_IDO_PASS:-1W0svLTg7Q1rKiQrYjdV}
DOCKER_ICINGAWEB_PASS=${DOCKER_ICINGAWEB_PASS:-T7CVdvA0mqzGN6pH5Ne4}
DOCKER_DASHING_API_USER=${DOCKER_DASHING_API_USER:-dashing}
DOCKER_DASHING_API_PASS=${DOCKER_DASHING_API_PASS:-icinga2ondashingr0xx}

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --detach \
  --publish=5665:5665 \
  --publish=6666:6666 \
  --volume=${PWD}/share/icinga2:/usr/local/monitoring \
  --link=${USER}-mysql:database \
  --link=${USER}-graphite:graphite \
  --env MYSQL_HOST=${DATABASE_IP} \
  --env MYSQL_PORT=3306 \
  --env MYSQL_USER=root \
  --env MYSQL_PASS=${DOCKER_DBA_ROOT_PASS} \
  --env IDO_PASSWORD=${DOCKER_IDO_PASS} \
  --env CARBON_HOST=${GRAPHITE_IP} \
  --env CARBON_PORT=2003 \
  --env DASHING_API_USER=${DOCKER_DASHING_API_USER} \
  --env DASHING_API_PASS=${DOCKER_DASHING_API_PASS} \
  --hostname=${USER}-${TYPE} \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
