# Athanor Kernel Module — Makefile
#
# Usage:
#   make              Build the module
#   make install      Build and install
#   make load         Build and load
#   make unload       Unload module
#   make clean        Clean build artifacts

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

.PHONY: all clean install load unload info

all:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) clean

install: all
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules_install
	depmod -a
	modprobe vitriol_alka

load: all
	sudo insmod vitriol_alka.ko
	dmesg | tail -20

unload:
	sudo rmmod vitriol_alka

info:
	modinfo vitriol_alka.ko
