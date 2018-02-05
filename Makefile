
.PHONY: base-container master satellite


base-container:
	cd build-from-source ;
	make

master:
	cd icinga2-master ;
	make

satellite:
	cd icinga2-satellite ;
	make

