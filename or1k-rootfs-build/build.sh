#!/bin/bash

set -ex

# Download anything missing

ROOT=/opt/rootfs
CACHE_DIR=${ROOT}/cache
PATCH_DIR=${ROOT}/patches
OUTPUT_DIR=${ROOT}/output

OR1K_GITHUB_SITE=https://github.com/openrisc
OR1K_TOOLCHAIN_SITE=https://github.com/stffrdhrn/or1k-toolchain-build/releases/download
BUILDROOT_TOOLCHAIN_SITE=https://toolchains.bootlin.com/downloads/releases/toolchains/openrisc/tarballs/
BUILDROOT_SITE=https://buildroot.org/downloads
BUSYBOX_SITE=https://busybox.net/downloads
KERNEL_SITE=https://cdn.kernel.org/pub/linux/kernel
QEMU_SITE=https://download.qemu.org

# Date used for artifacts
arc_date=`date -u +%Y%m%d`
version=${arc_date}

package_url()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  if [[ $ver = or1k-* ]]; then
    short_ver=${ver:5}
    case $pkg in
      or1k-*) echo $OR1K_TOOLCHAIN_SITE/${ver}/${pkg}-${short_ver}.tar.xz ;;
      # Not a toolchain, an actual package
      *)      echo $OR1K_GITHUB_SITE/${pkg}/archive/${ver}.tar.gz ;;
    esac
    return
  fi

  case $pkg in
    or1k-buildroot-linux-musl-) echo $BUILDROOT_TOOLCHAIN_SITE/openrisc--musl--${ver}.tar.xz ;;
    or1k-buildroot-linux-gnu-) echo $BUILDROOT_TOOLCHAIN_SITE/openrisc--glibc--${ver}.tar.xz ;;
    or1k-buildroot-linux-uclibc-) echo $BUILDROOT_TOOLCHAIN_SITE/openrisc--uclibc--${ver}.tar.xz ;;
    buildroot) echo $BUILDROOT_SITE/${pkg}-${ver}.tar.xz ;;
    busybox)   echo $BUSYBOX_SITE/${pkg}-${ver}.tar.bz2 ;;
    linux)     echo $KERNEL_SITE/v${ver:0:1}.x/linux-${ver}.tar.xz ;;
    qemu)      echo $QEMU_SITE/${pkg}-${ver}.tar.xz ;;
  esac
}

package_tarball()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  typeset url=$(package_url $pkg $ver)
  echo $CACHE_DIR/$(basename $url)
}

check_and_download()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  typeset url=$(package_url $pkg $ver)

  filename=`basename $url`
  if [ ! -f $CACHE_DIR/$filename ] ; then
    wget --directory-prefix=$CACHE_DIR $url
    sha1sum $CACHE_DIR/$filename > $CACHE_DIR/$filename.sha1
  fi
}

archive_src()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  case $pkg in
    or1k-buildroot-linux-musl-) echo $PWD/openrisc--musl--${ver} ;;
    or1k-buildroot-linux-gnu-) echo $PWD/openrisc--glibc--${ver} ;;
    or1k-buildroot-linux-uclibc-) echo $PWD/openrisc--uclibc--${ver} ;;
    # FIXME openrisc toolchain pkgs have no version, need to fix
    # or1k-toolchain-build
    or1k-none-*) echo $PWD/$pkg ;;
    *) echo $PWD/${pkg}-${ver} ;;
  esac
}

archive_extract()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  # First check if the archive is available, if not, get it
  check_and_download $pkg $ver

  typeset src=$(archive_src $pkg $ver)

  # Next extract it to the current directory if we
  # haven't already, may have been for binutils-gdb
  if [ ! -d $src ] ; then
    tar -xf $(package_tarball $pkg $ver)

    # Apply any patches
    if [ -d ${PATCH_DIR}/${pkg} ] ; then
       for patch in ${PATCH_DIR}/${pkg}/*.patch ; do
         patch -d $src -p1 < $patch
       done
    fi
  fi
}

gen_release_notes()
{
  {

    echo "## OpenRISC Rootfs $version"
    echo "These rootfs images were built using the "
    echo "[or1k-rootfs-build](https://github.com/stffrdhrn/or1k-rootfs-build) "
    echo " environment configured with the following versions: "
    echo " - toolchain_version : $crosstool_pkg ${CROSSTOOL_VERSION}"
    if [ $BUSYBOX_ENABLED ] ; then
      echo " - busybox : ${BUSYBOX_VERSION}"
    fi
    if [ $BUILDROOT_ENABLED ] ; then
      echo " - buildroot : ${BUILDROOT_VERSION}"
    fi
    echo
    if [ $TEST_ENABLED ] ; then
    echo "## Test Results"
      echo "Tests for rootfs images were run using qemu and kernel versions:"
      echo " - linux : ${LINUX_VERSION}"
      echo " - qemu : ${QEMU_VERSION}"
    fi

  } > /opt/rootfs/output/relnotes-${version}.md
}

# m4 config creates some files that connot be removed in docker/podman
# just move them away, otherwise they cause the make clean to fail.
remove_confdir3() {
  local src=$1; shift

  for baddir in `find $src -maxdepth 4 -name confdir3`; do
    mv $baddir $(mktemp --tmpdir -d confdir.junk.XXX)
  done
}

# Get the toolchain
crosstool_pkg=${CROSSTOOL:0:-1}
archive_extract $crosstool_pkg ${CROSSTOOL_VERSION}
export PATH=$(archive_src $crosstool_pkg ${CROSSTOOL_VERSION})/bin:$PATH
export BUILDDIR=$PWD

echo PATH: $PATH
${CROSSTOOL}gcc --version

# Get latest build and config scripts

if [ ! -d "or1k-utils" ] ; then
  git clone --depth=1 https://github.com/stffrdhrn/or1k-utils.git
fi
OR1K_UTILS=$PWD/or1k-utils

# Setup testing infra, qemu also used for buildroot mkimg

if [ $TEST_ENABLED ] || [ $BUILDROOT_ENABLED ] ; then

  export QEMU_SRC=$(archive_src qemu ${QEMU_VERSION})
  if [ ! -d "$QEMU_SRC" ] ; then
    archive_extract qemu ${QEMU_VERSION}

    mkdir $QEMU_SRC/build
    cd $QEMU_SRC/build
       $OR1K_UTILS/qemu/config.qemu
       make -j$(nproc)
       $QEMU_SRC/build/qemu-or1k
    cd ../..
  fi
fi
if [ $TEST_ENABLED ] ; then
    export LINUX_SRC=$(archive_src linux ${LINUX_VERSION})
    archive_extract linux ${LINUX_VERSION}
fi

# Build Busybox cpio

if [ $BUSYBOX_ENABLED ] ; then
  archive_extract busybox ${BUSYBOX_VERSION}
  export BUSYBOX_SRC=$(archive_src busybox ${BUSYBOX_VERSION})
  $OR1K_UTILS/busybox/busybox.build

  if [ $TEST_ENABLED ] ; then
    TOOLCHAIN=$CROSSTOOL \
    $OR1K_UTILS/scripts/make-or1k-linux defconfig

    TOOLCHAIN=$CROSSTOOL \
    INITRAMFS_SOURCE="$PWD/busybox-rootfs/initramfs  $PWD/busybox-rootfs/initramfs.devnodes" \
    $OR1K_UTILS/scripts/make-or1k-linux

    LOG_FILE=$PWD/busybox-rootfs/qemu-or1k-busybox-test.log ./qemu-or1k-busybox.exp
  fi
fi

# Build buildroot image

if [ $BUILDROOT_ENABLED ] ; then
  archive_extract buildroot ${BUILDROOT_VERSION}

  export BUILDROOT_SRC=$(archive_src buildroot ${BUILDROOT_VERSION})
  # because our container is root!
  export FORCE_UNSAFE_CONFIGURE=1
  $OR1K_UTILS/buildroot/buildroot.build qemu_or1k_defconfig
  $OR1K_UTILS/buildroot/buildroot.build

  mv buildroot-rootfs buildroot-qemu-rootfs

  remove_confdir3 $BUILDROOT_SRC
  $OR1K_UTILS/buildroot/buildroot.build clean
  $OR1K_UTILS/buildroot/buildroot.build litex_mor1kx_defconfig
  $OR1K_UTILS/buildroot/buildroot.build

  mv buildroot-rootfs buildroot-litex-rootfs

  # We only test the qemu image, but oh well
  if [ $TEST_ENABLED ] ; then
    $OR1K_UTILS/scripts/make-or1k-linux clean

    TOOLCHAIN=$CROSSTOOL \
    $OR1K_UTILS/scripts/make-or1k-linux virt_defconfig

    TOOLCHAIN=$CROSSTOOL \
    $OR1K_UTILS/scripts/make-or1k-linux

    LOG_FILE=$PWD/buildroot-qemu-rootfs/qemu-or1k-buildroot-test.log ./qemu-or1k-buildroot.exp
  fi
fi

gen_release_notes
