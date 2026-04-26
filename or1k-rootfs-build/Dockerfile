FROM debian:latest
RUN apt-get update && apt-get install -y \
 build-essential \
 git \
 file cpio unzip rsync bc \
 python3.11-dev pip ninja-build glib-2.0-dev \
 fdisk parted libnbd-bin fuse3 \
 bison flex \
 expect \
 wget

LABEL maintainer Stafford Horne <shorne@gmail.com>

# Default build versions
ENV CROSSTOOL=or1k-none-linux-musl-
ENV CROSSTOOL_VERSION=or1k-15.2.0-20260425
ENV BUILDROOT_VERSION=2026.02
ENV BUSYBOX_VERSION=1.37.0
ENV QEMU_VERSION=10.2.2
ENV LINUX_VERSION=6.18.22
ENV TEST_ENABLED=1

# Make volume mount points for output + cache of tarballs
RUN mkdir -p /opt/rootfs/output \
 && mkdir -p /opt/rootfs/cache \
 && mkdir -p /opt/rootfs/build
VOLUME ["/opt/rootfs/output", "/opt/rootfs/cache"]

WORKDIR /opt/rootfs/build

# Clone this to lock in the code and not get suprises
run git clone https://github.com/jrwwallis/qcow2fuse.git

COPY *.sh *.exp /opt/rootfs/build/
ADD patches /opt/rootfs/patches

CMD ./build.sh && ./package.sh
