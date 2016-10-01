
CONTAINER  := icinga2
IMAGE_NAME := docker-icinga2

DATA_DIR   := /tmp/docker-data
MYSQL_ROOT_PASSWORD := $(MYSQL_ROOT_PASSWORD)


build:
	docker \
		build \
		--rm --tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

run:
	docker \
		run \
		--detach \
		--interactive \
		--tty \
		--publish=5665:5665 \
		--publish=6666:6666 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${CONTAINER} \
		--name=${CONTAINER} \
		$(IMAGE_NAME)

shell:
	docker \
		run \
		--rm \
		--interactive \
		--tty \
		--publish=5665:5665 \
		--publish=6666:6666 \
		--volume=${DATA_DIR}:/srv \
		--hostname=${CONTAINER} \
		--name=${CONTAINER} \
		$(IMAGE_NAME)

exec:
	docker \
		exec \
		--interactive \
		--tty \
		${CONTAINER} \
		/bin/bash

stop:
	docker \
		kill ${CONTAINER}

history:
	docker \
		history ${IMAGE_NAME}

