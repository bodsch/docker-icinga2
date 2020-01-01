.DEFAULT_GOAL := list

stack-name-ic2s1 = icinga2
stack-name-ic2s2  = icinga2_s2

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

deploy-icinga2:
	docker stack deploy \
	--with-registry-auth \
	-c docker-compose-icinga2.yml \
	$(stack-name-ic2s1)

deploy-icinga2_s2:
	docker stack deploy \
	--with-registry-auth \
	-c docker-compose-icinga2_s2.yml \
	$(stack-name-ic2s2)

un-deploy-icinga2:
	docker stack remove $(stack-name-ic2s1)

un-deploy-icinga2_s2:
	docker stack remove $(stack-name-ic2s2)

re-deploy:
	docker stack remove $(stack-name); \
	\
	docker stack deploy \
	--with-registry-auth \
	-c docker-compose.yml \
	$(stack-name)

network:
	docker network create --driver=overlay icinga2_backend
