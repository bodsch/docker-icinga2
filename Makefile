
CONTAINER  := icinga2
IMAGE_NAME := docker-icinga2

DATA_DIR   := /tmp/docker-data

build:
	docker \
		build \
		--rm --tag=$(IMAGE_NAME) .
	@echo Image tag: ${IMAGE_NAME}

clean:
	docker \
		rmi \
		${IMAGE_NAME}

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
		--publish=4567:4567 \
		--env ICINGA_MASTER=${CONTAINER}.matrix.lan \
		--env ICINGA_API_USERS='root:icinga,dashing:dashing,cert:foo-bar' \
		--env ICINGA_CERT_SERVICE=true \
		--env ICINGA_CERT_SERVICE_BA_USER=foo \
		--env ICINGA_CERT_SERVICE_BA_PASSWORD=bar \
		--env ICINGA_CERT_SERVICE_API_USER=root \
		--env ICINGA_CERT_SERVICE_API_PASSWORD=icinga \
		--env ICINGA_CERT_SERVICE_SERVER=192.168.252.5 \
		--env ICINGA_CERT_SERVICE_PORT=4567 \
		--env ICINGA_SSMTP_RELAY_SERVER=mail.domain.tld:25 \
		--env ICINGA_SSMTP_REWRITE_DOMAIN=domain.tld \
		--env ICINGA_SSMTP_SENDER_EMAIL=icinga \
		--env ICINGA_SSMTP_SMTPAUTH_USER=foo.bar@domain.tld \
		--env ICINGA_SSMTP_SMTPAUTH_PASS=tribbleX \
		--env ICINGA_SSMTP_RELAY_USE_STARTTLS=true \
		--env ICINGA_SSMTP_ALIASES= \
		--volume=${DATA_DIR}:/srv \
		--hostname=${CONTAINER}.matrix.lan \
		--name=${CONTAINER} \
		$(IMAGE_NAME) \
		/bin/sh

exec:
	docker \
		exec \
		--interactive \
		--tty \
		${CONTAINER} \
		/bin/sh

stop:
	docker \
		kill ${CONTAINER}

history:
	docker \
		history ${IMAGE_NAME}

compose-up:
	docker-compose \
		--file docker-compose_example.yml \
		--project-name icinga-test \
		up \
		--build \
		--abort-on-container-exit \
		--remove-orphans

compose-down:
	docker-compose \
		--file docker-compose_example.yml \
		--project-name icinga-test \
		down \
		--rmi all

