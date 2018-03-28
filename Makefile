
.PHONY: ALL base-container icinga2-master icinga2-satellite clean

NS       := bodsch
REPO     := docker-icinga2

BUILD_DATE := $(shell date +%Y-%m-%d)

default:
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  params                 Print build parameter"
	@echo "  build                  Build images"
	@echo "  version                Print version of images"
	@echo "  test                   Test images"
	@echo "  publish                Publish images"
	@echo ""


params:
	@echo ""
	@echo " ICINGA2_VERSION: ${ICINGA2_VERSION}"
	@echo " ICINGA2_VCS_REF: ${ICINGA2_VCS_REF}"
	@echo " BUILD_DATE     : $(BUILD_DATE)"
	@echo ""

build:	base-container 	icinga2-master	icinga2-satellite


base-container: params
	cd build-from-source ; \
	docker build \
		--rm \
		--compress \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VCS_REF=${ICINGA2_VCS_REF} \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-source-$(ICINGA2_VCS_REF) . ; \
	cd ..

icinga2-master: params
	@echo ""
	@echo " build icinga2-master"
	@echo ""
	cd icinga2-master ; \
	docker build \
		--rm \
		--compress \
		--no-cache \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VCS_REF=${ICINGA2_VCS_REF} \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-master-$(ICINGA2_VCS_REF) . ; \
	cd ..

icinga2-satellite: params
	@echo ""
	@echo " build icinga2-satellite"
	@echo ""
	cd icinga2-satellite ; \
	docker build \
		--rm \
		--compress \
		--no-cache \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg ICINGA2_VCS_REF=${ICINGA2_VCS_REF} \
		--build-arg ICINGA2_VERSION=${ICINGA2_VERSION} \
		--tag $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite-$(ICINGA2_VCS_REF) . ; \
	cd ..

clean:
	docker rmi -f `docker images -q ${NS}/${REPO} | uniq`

#
# List all images
#
list:
	-docker images $(NS)/$(REPO)*

publish:
	# amd64 / community / cpy3
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-source-$(ICINGA2_VCS_REF)
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-master-$(ICINGA2_VCS_REF)
	docker push $(NS)/$(REPO):$(ICINGA2_VERSION)-satellite-$(ICINGA2_VCS_REF)

compose: params
	docker-compose --file docker-compose_example.yml up --build
