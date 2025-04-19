.PHONY: image run run-debug pull help

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
DOCKER_EXTRA_ARGS :=
DOCKER_RUN := $(DOCKER) run -it --rm \
 -e BUILDROOT_ENABLED=$(BUILDROOT_ENABLED) \
 -e BUSYBOX_ENABLED=$(BUSYBOX_ENABLED) \
 $(VERSIONS) \
 -v $(OUTPUTDIR):/opt/rootfs/output:Z \
 -v $(CACHEDIR):/opt/rootfs/cache:Z \
 --device=/dev/fuse \
 --privileged \
 $(DOCKER_EXTRA_ARGS) \
 or1k-rootfs-build

$(OUTPUTDIR):
	mkdir -p $(OUTPUTDIR)
$(CACHEDIR):
	mkdir -p $(CACHEDIR)

/dev/fuse:
	@echo /dev/fuse does not exist, run 'modprobe fuse'
	@exit 1
pull:
	$(DOCKER) image pull debian:latest
image: or1k-rootfs-build/Dockerfile
	$(DOCKER) build -t or1k-rootfs-build or1k-rootfs-build/
run: $(VOLUMES) /dev/fuse
	$(DOCKER_RUN)
run-debug: $(VOLUMES) /dev/fuse
	$(DOCKER_RUN) bash
help:
	@echo "This is the helper file for running the rootfs build."
	@echo "Run one of the targets:"
	@echo
	@echo "  - help      - prints this help"
	@echo "  - pull      - pull upstream image for an refreshed image build."
	@echo "  - image     - builds the docker image and default volume directories."
	@echo "  - run       - runs the docker image"
	@echo "  - run-debug - runs the docker image in debug mode"
	@echo
	@echo "Configured setup:"
	@echo "  DOCKER:     $(DOCKER)"
	@echo "  DOCKER_RUN: $(DOCKER_RUN)"
	@echo "  OUTPUTDIR:  $(OUTPUTDIR)"
	@echo "  CACHEDIR:   $(CACHEDIR)"
