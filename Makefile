# Copyright (C) 2017 Luca Filipozzi <luca.filipozzi@gmail.com>
# Released subject to the terms of the Mozilla Public License.
#
VERSION = 7.11.0
# VERSION = 9.12.0
#ARCH = amd64
ARCH=i386

QEMU_SYSTEM = qemu-system-x86_64

ifeq ($(ARCH),amd64)
INSTALL_PATH = install.amd
# QEMU_SYSTEM = qemu-system-x86_64
else ifeq ($(ARCH),i386)
INSTALL_PATH = install.386
# QEMU_SYSTEM = qemu-system-i386
endif


SHELL = /bin/bash

bootargs  = auto
bootargs += console-keymaps-at/keymap=us
bootargs += console-setup/ask_detect=false
bootargs += debconf/frontend=noninteractive
bootargs += debian-installer=en_US
bootargs += fb=false
bootargs += install
bootargs += kbd-chooser/method=us
bootargs += keyboard-configuration/xkb-keymap=us
bootargs += locale=en_US
bootargs += netcfg/get_domain=debian.local
bootargs += netcfg/get_hostname=vm
bootargs += preseed/url=http://10.0.2.2:8000/preseed.cfg

.PHONY: default
default: build

.PHONY: build
build: disk.qcow2

.PHONY: clean
clean:
	rm -f disk.qcow2 disk.img kernel initrd netinst.iso

.PHONY: distclean
distclean: clean
	rm -f debian-$(VERSION)-amd64-netinst.iso

.ONESHELL:
disk.qcow2: disk.img kernel initrd netinst.iso
	python3 -m http.server &> server.log & \
		echo $$! > server.pid && \
		sleep 1
	$(QEMU_SYSTEM) -m size=1G -smp cpus=2 -display curses \
	  -drive if=virtio,file=disk.img,format=raw,index=0,cache=unsafe \
	  -accel hvf -cpu host \
	  -cdrom netinst.iso -boot d -no-reboot \
	  -nic user,id=eth0 \
	  -kernel kernel -initrd initrd -append "${bootargs}"
	qemu-img convert -f raw -O qcow2 disk.img disk.qcow2
	kill $$(cat server.pid)
	rm server.pid

.INTERMEDIATE: disk.img
disk.img:
	qemu-img create -f raw disk.img 4G

.INTERMEDIATE: kernel
kernel: netinst.iso
	isoinfo -R -J -i netinst.iso -x /$(INSTALL_PATH)/vmlinuz > $@

.INTERMEDIATE: initrd
initrd: netinst.iso
	isoinfo -R -J -i netinst.iso -x /$(INSTALL_PATH)/initrd.gz > $@

.INTERMEDIATE: netinst.iso
netinst.iso: debian-$(VERSION)-$(ARCH)-netinst.iso
	ln -sf $^ $@

.PRECIOUS: debian-$(VERSION)-$(ARCH)-netinst.iso
debian-$(VERSION)-$(ARCH)-netinst.iso:
	wget -c -N https://cdimage.debian.org/cdimage/archive/$(VERSION)/$(ARCH)/iso-cd/debian-$(VERSION)-$(ARCH)-netinst.iso

