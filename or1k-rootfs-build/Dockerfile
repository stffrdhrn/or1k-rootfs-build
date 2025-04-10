FROM debian:latest
RUN apt-get update && apt-get install -y \
 build-essential \
 git \
 file cpio unzip rsync bc \
 python3.11-dev pip ninja-build glib-2.0-dev \
 fdisk parted libnbd-bin fuse3 \
 wget

LABEL maintainer Stafford Horne <shorne@gmail.com>

# Default build versions
ENV CROSSTOOL=or1k-none-linux-musl-
ENV CROSSTOOL_VERSION=or1k-14.2.0-20250405
ENV BUILDROOT_VERSION=2025.02
ENV BUSYBOX_VERSION=1.37.0
ENV QEMU_VERSION=9.2.2

# Make volume mount points for output + cache of tarballs
RUN mkdir -p /opt/rootfs/output \
 && mkdir -p /opt/rootfs/cache \
 && mkdir -p /opt/rootfs/build
VOLUME ["/opt/rootfs/output", "/opt/rootfs/cache"]

WORKDIR /opt/rootfs/build

# Clone this to lock in the code and not get suprises
run git clone https://github.com/jrwwallis/qcow2fuse.git

COPY *.sh /opt/rootfs/build/
ADD patches /opt/rootfs/patches

CMD ./build.sh && ./package.sh
