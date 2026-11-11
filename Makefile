obj-m	:= src/facer.o

KERNELDIR ?= $(shell if [ -d "/lib/modules/$(shell uname -r)/build" ]; then \
		echo "/lib/modules/$(shell uname -r)/build"; \
	else \
		echo "/usr/lib/modules/$(shell uname -r)/build"; \
	fi)
PWD       := $(shell pwd)

# Sign the kernel module for secure boot (Ubuntu)
# https://wiki.ubuntu.com/UEFI/SecureBoot/Signing
KEY := /var/lib/shim-signed/mok/MOK.priv
X509 := /var/lib/shim-signed/mok/MOK.der

ifdef LTS
    ccflags-y := -Dlts
endif

all: default

default:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

	if [ -f "$(KEY)" ] && [ -f "$(X509)" ]; then \
		sudo kmodsign sha512 $(KEY) $(X509) src/facer.ko; \
	fi

install:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules_install

clean:
	rm -rf src/*.o src/*~ src/.*.cmd src/*.ko src/*.mod.c \
		.tmp_versions modules.order Module.symvers

DKMS_VER := $(shell grep PACKAGE_VERSION dkms.conf 2>/dev/null | cut -d= -f2 | tr -d '"')

dkmsclean:
	@dkms remove facer/$(DKMS_VER) --all || true
	@dkms remove facer/0.1 --all || true
	@dkms remove facer/0.2 --all || true

dkms: dkmsclean
	dkms add .
	dkms install -m facer -v $(DKMS_VER)

onboot:
	echo "facer" > /etc/modules-load.d/facer.conf

noboot:
	rm -f /etc/modules-load.d/facer.conf