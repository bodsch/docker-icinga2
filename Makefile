
.PHONY: ALL base-container icinga2-master icinga2-satellite clean

NS       := bodsch
REPO     := docker-icinga2

BUILD_DATE      := $(shell date +%Y-%m-%d)
BUILD_VERSION   := $(shell date +%y%m)

CERT_SERVICE_TYPE    ?= stable
CERT_SERVICE_VERSION ?= 0.18.1

ICINGA2_VERSION ?= 2.9.1

default:	build

#default:
#	@echo ""
#	@echo "Targets:"
#	@echo ""
#	@echo "  params                 Print build parameter"
#	@echo "  build                  Build images"
#	@echo "  alpine                 meta target for the following 3 sub targets:"
#	@echo "   base-alpine              build a base container for"
#	@echo "   icinga2-alpine-master    build an icinga2 master"
#	@echo "   icinga2-alpine-satellite build an icinga2 satellite"
#	@echo "  compose-alpine         creates an demo docker-compose.yaml for alpine"
#	@echo "  debian                 meta target for the followinf 3 sub targets:"
#	@echo "   base-debian              build a base container for"
#	@echo "   icinga2-debian-master    build an icinga2 master"
#	@echo "   icinga2-debian-satellite build an icinga2 satellite"
#	@echo "  compose-debian         creates an demop docker-compose.yaml for debain"
#	@echo "  base                   builds all base container"
#	@echo "  master                 builds all icinga2 masters"
#	@echo "  satellite              builds all icinga2 satellites"
#	@echo "  compose-debian         creates an demo docker-compose.yaml for debain"
##	@echo "  version                Print version of images"
##	@echo "  publish                Publish images"
#	@echo ""
#	@echo "  list                   list all conatiner with a $(REPO) tag"
#	@echo "  clean                  remove all conatiner with a $(REPO) tag"
#

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
	docker-compose \
		--file compose/head.yml \
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

#publish:
#	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)
#	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-master
#	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite
