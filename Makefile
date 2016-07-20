TYPE := icinga2
IMAGE_NAME := ${USER}-docker-${TYPE}
DATA_DIR := /tmp/docker-data
MYSQL_ROOT_PASSWORD := $(MYSQL_ROOT_PASSWORD)


build:
	mkdir -vp ${DATA_DIR}
	docker build --rm --tag=$(IMAGE_NAME) .

run:
	docker run \
		--detach \
		--interactive \
		--tty \
		--publish=5665:5665 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${USER}-mysql \
		--name=${USER}-${TYPE} \
		$(IMAGE_NAME)

shell:
	docker run \
		--rm \
		--interactive \
		--tty \
		--publish=5665:5665 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${USER}-mysql \
		--name=${USER}-${TYPE} \
		$(IMAGE_NAME)

exec:
	docker exec \
		--interactive \
		--tty \
		${USER}-${TYPE} \
		/bin/sh

stop:
	docker kill \
		${USER}-${TYPE}
