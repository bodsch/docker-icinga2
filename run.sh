#!/bin/bash

. config.rc

if [ $(docker ps -a | grep ${CONTAINER_NAME} | awk '{print $NF}' | wc -l) -gt 0 ]
then
  docker kill ${CONTAINER_NAME} 2> /dev/null
  docker rm   ${CONTAINER_NAME} 2> /dev/null
fi

# ---------------------------------------------------------------------------------------

docker run \
  --interactive \
  --tty \
  --detach \
  --publish=5665:5665 \
  --volume=${PWD}/share/icinga2:/usr/local/share/icinga2 \
  --hostname=${USER}-${TYPE} \
  --link=database:${USER}-mysql \
  --env MYSQL_HOST=${USER}-mysql \
  --env MYSQL_USER=root \
  --env MYSQL_PASS= \
  --name ${CONTAINER_NAME} \
  ${TAG_NAME}

# ---------------------------------------------------------------------------------------
# EOF
