
NS       := bodsch
REPO     := docker-icinga2

BUILD_DATE      := $(shell date +%Y-%m-%d)
BUILD_VERSION   := $(shell date +%y%m)

CERT_SERVICE_TYPE    ?= stable
CERT_SERVICE_VERSION ?= 0.18.3
ICINGA2_VERSION      ?= 2.10.2

.PHONY: icinga2-master icinga2-satellite compose-file clean master-shell satellite-shell list release

default:	build

params:
	@echo ""
	@echo " ICINGA2_VERSION: ${ICINGA2_VERSION}"
	@echo " BUILD_DATE     : $(BUILD_DATE)"
	@echo ""

build: icinga2-master	icinga2-satellite	compose-file

icinga2-master: params
	@echo ""
	@echo " build debian based icinga2-master"
	@echo ""
	docker build \
		--file Dockerfile.master \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--build-arg CERT_SERVICE_TYPE=${CERT_SERVICE_TYPE} \
		--build-arg CERT_SERVICE_VERSION=${CERT_SERVICE_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-master .

icinga2-satellite: params
	@echo ""
	@echo " build debian based icinga2-satellite"
	@echo ""
	docker build \
		--file Dockerfile.satellite \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite .

compose-file:	params
	echo "BUILD_DATE=$(BUILD_DATE)" > .env
	echo "BUILD_VERSION=$(BUILD_VERSION)" >> .env
	echo "ICINGA2_VERSION=$(ICINGA2_VERSION)" >> .env
	echo "MYSQL_ROOT_PASS=vYUQ14SGVrJRi69PsujC" >> .env
	echo "IDO_PASSWORD=qUVuLTk9oEDUV0A" >> .env
	docker-compose \
		--file compose/head.yml \
		--file compose/nginx.yml \
		--file compose/database.yml \
		--file compose/icingaweb2.yml \
		--file compose/master.yml \
		--file compose/satellite.yml \
		config > docker-compose.yml

clean:
	docker rmi -f `docker images -q ${NS}/${REPO} | uniq`

master-shell:
	docker run \
		--rm \
		--name icinga2-master \
		--hostname icinga2-master.matrix.lan \
		--interactive \
		--tty \
		$(NS)/$(REPO):$(ICINGA2_VERSION)-master \
		/bin/bash

satellite-shell:
	docker run \
		--rm \
		--name icinga2-satellite \
		--hostname icinga2-satellite.matrix.lan \
		--interactive \
		--tty \
		$(NS)/$(REPO):$(ICINGA2_VERSION)-satellite \
		/bin/bash

#
# List all images
#
list:
	-docker images $(NS)/$(REPO)*

release:
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-master
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite
	docker tag $(NS)/$(REPO):$(ICINGA2_VERSION)-master    $(NS)/$(REPO):latest-master
	docker tag $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite $(NS)/$(REPO):latest-satellite
	docker push $(NS)/$(REPO):latest-master
	docker push $(NS)/$(REPO):latest-satellite
