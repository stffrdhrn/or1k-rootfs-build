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

    echo "## OpenRISC GCC Rootfs $version"
    echo "These rootfs images were built using the "
    echo "[or1k-rootfs-build](https://github.com/stffrdhrn/or1k-rootfs-build) "
    echo " environment configured with the following versions: "
    echo " - toolchain_version : ${TOOLCHAIN_VERSION}"
    if [ $BUSYBOX_ENABLED ] ; then
      echo " - busybox : ${BUSYBOX_VERSION}"
    fi
    if [ $BUILDROOT_ENABLED ] ; then
      echo " - buildroot : ${BUILDROOT_VERSION}"
    fi
    echo
    if [ $TEST_ENABLED ] ; then
    echo "## Test Results"
      echo "Tests for toolchains were run using dejagnu board configs found in"
      echo "[or1k-utils](https://github.com/stffrdhrn/or1k-utils)."
      echo "The test results for the toolchains are as follows:"
    fi

  } > /opt/rootfs/output/relnotes-${version}.md
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

  QEMU_PREFIX=$PWD/or1k-qemu
  if [ ! -d "$QEMU_PREFIX" ] ; then
    archive_extract qemu ${QEMU_VERSION}
    export QEMU_SRC=$(archive_src qemu ${QEMU_VERSION})

    mkdir $QEMU_SRC/build
    cd $QEMU_SRC/build
       $OR1K_UTILS/qemu/config.qemu --prefix=$QEMU_PREFIX
       make -j5
       make install
       $QEMU_PREFIX/bin/qemu-or1k
    cd ../..
  fi

  export PATH=$QEMU_PREFIX/bin:$PATH
fi

# Build Busbox cpio

if [ $BUSYBOX_ENABLED ] ; then
  archive_extract busybox ${BUSYBOX_VERSION}
  export BUSYBOX_SRC=$(archive_src busybox ${BUSYBOX_VERSION})
  $OR1K_UTILS/busybox/busybox.build
fi

# Build buildroot image

# Cheap sudo pass through as we are root in this container
sudo() {
 $@
}

if [ $BUILDROOT_ENABLED ] ; then
  mkdir buildroot; cd buildroot
    archive_extract buildroot ${BUILDROOT_VERSION}

    export BUILDROOT_SRC=$(archive_src buildroot ${BUILDROOT_VERSION})
    # because our container is root!
    export FORCE_UNSAFE_CONFIGURE=1
    export -f sudo
    $OR1K_UTILS/buildroot/buildroot.build qemu_or1k_defconfig
    $OR1K_UTILS/buildroot/buildroot.build
  cd ..
fi

gen_release_notes
