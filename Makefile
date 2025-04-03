.PHONY: image run run-bash

OUTPUTDIR      := $(HOME)/work/docker/volumes/rootfs/output
CACHEDIR       := $(HOME)/work/docker/volumes/rootfs/cache

VOLUMES        := $(OUTPUTDIR) $(CACHEDIR)

BUILDROOT_ENABLED := 1
BUSYBOX_ENABLED   := 1
TEST_ENABLED      := 1

# Use default versions from docker
CROSSTOOL_VERSION :=
CROSSTOOL         :=
BUILDROOT_VERSION :=
BUSYBOX_VERSION   :=
QEMU_VERSION      :=

VERSIONS :=
VERSIONS += $(if $(CROSSTOOL),-e CROSSTOOL=$(CROSSTOOL),)
VERSIONS += $(if $(CROSSTOOL_VERSION),-e CROSSTOOL_VERSION=$(CROSSTOOL_VERSION),)
VERSIONS += $(if $(BUILDROOT_VERSION),-e BUILDROOT_VERSION=$(BUILDROOT_VERSION),)
VERSIONS += $(if $(BUSYBOX_VERSION),-e BUSYBOX_VERSION=$(BUSYBOX_VERSION),)
VERSIONS += $(if $(QEMU_VERSION),-e QEMU_VERSION=$(QEMU_VERSION),)

DOCKER := podman
DOCKER_RUN := $(DOCKER) run -it --rm \
 -e BUILDROOT_ENABLED=$(BUILDROOT_ENABLED) \
 -e BUSYBOX_ENABLED=$(BUSYBOX_ENABLED) \
 $(VERSIONS) \
 -v $(OUTPUTDIR):/opt/rootfs/output:Z \
 -v $(CACHEDIR):/opt/rootfs/build/cache:Z \
 or1k-rootfs-build

$(OUTPUTDIR):
	mkdir -p $(OUTPUTDIR)
$(CACHEDIR):
	mkdir -p $(CACHEDIR)

image: or1k-rootfs-build/Dockerfile
	$(DOCKER) build -t or1k-rootfs-build or1k-rootfs-build/
run: $(VOLUMES)
	$(DOCKER_RUN)
run-bash: $(VOLUMES)
	$(DOCKER_RUN) bash
