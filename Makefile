
.PHONY: ALL base-container icinga2-master icinga2-satellite clean

NS       := bodsch
REPO     := docker-icinga2

BUILD_DATE      := $(shell date +%Y-%m-%d)
BUILD_VERSION   := $(shell date +%y%m)
ICINGA2_VERSION ?= 2.8.4

default:
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  params                 Print build parameter"
	@echo "  build                  Build images"
#	@echo "  version                Print version of images"
	@echo "  test                   Test images"
	@echo "  publish                Publish images"
	@echo ""


params:
	@echo ""
	@echo " ICINGA2_VERSION: ${ICINGA2_VERSION}"
	@echo " BUILD_DATE     : $(BUILD_DATE)"
	@echo ""

build: base-alpine base-debian	icinga2-master	icinga2-satellite

base:	params	base-debian	base-alpine
master:	params	icinga2-alpine-master	icinga2-debian-master


base-debian: params
	@echo ""
	@echo " build debian based icinga2 base container"
	@echo ""
	cd icinga2-debian ; \
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-debian . ; \
	cd ..

base-alpine: params
	@echo ""
	@echo " build alpine based icinga2 base container"
	@echo ""
	cd icinga2-alpine ; \
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-alpine . ; \
	cd ..

icinga2-alpine-master: params
	@echo ""
	@echo " build alpine based icinga2-master"
	@echo ""
	cd icinga2-master ; \
	docker build \
		--file Dockerfile.alpine \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-alpine-master . ; \
	cd ..


icinga2-debian-master: params
	@echo ""
	@echo " build debian based icinga2-master"
	@echo ""
	cd icinga2-master ; \
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-debian-master . ; \
	cd ..

icinga2-satellite: params
	@echo ""
	@echo " build icinga2-satellite"
	@echo ""
	cd icinga2-satellite ; \
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite . ; \
	cd ..

clean:
	docker rmi -f `docker images -q ${NS}/${REPO} | uniq`

shell:
	docker run \
		--rm \
		--name docker-icinga2-default \
		--interactive \
		--tty \
		$(NS)/$(REPO):$(ICINGA2_VERSION)-alpine-master \
		/bin/sh

#
# List all images
#
list:
	-docker images $(NS)/$(REPO)*

publish:
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-master
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite

compose: params
	docker-compose --file docker-compose_example.yml up --build
