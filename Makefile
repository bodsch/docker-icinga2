
base-container:
	cd build-from-source; make

icinga2-master:    base-container
	cd icinga2-master; make

icinga2-satellite:  base-container
	cd icinga2-satellite; make

ALL:
	$(base-container) $(icinga2-master) $(icinga2-satellite)

clean:
	cd build-from-source; make clean;
	cd icinga2-master; make clean;
	cd icinga2-satellite; make clean;

#.PHONY base-container master satellite
