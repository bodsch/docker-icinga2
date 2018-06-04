
.PHONY: ALL base-container icinga2-master icinga2-satellite clean

NS       := bodsch
REPO     := docker-icinga2

BUILD_DATE := $(shell date +%Y-%m-%d)
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

build: base-debian	icinga2-master	icinga2-satellite

base-debian: params
	@echo ""
	@echo " build icinga2 base"
	@echo ""
	cd icinga2-debian ; \
	docker build \
		--force-rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION) . ; \
	cd ..

icinga2-master: params
	@echo ""
	@echo " build icinga2-master"
	@echo ""
	cd icinga2-master ; \
	docker build \
		--force-rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-master . ; \
	cd ..

icinga2-satellite: params
	@echo ""
	@echo " build icinga2-satellite"
	@echo ""
	cd icinga2-satellite ; \
	docker build \
		--force-rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite . ; \
	cd ..

clean:
	docker rmi -f `docker images -q ${NS}/${REPO} | uniq`

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
