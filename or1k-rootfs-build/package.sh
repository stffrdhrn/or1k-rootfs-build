#!/bin/bash

set -ex

version=`date -u +%Y%m%d`

package_dir()
{
  declare dir=$1 ; shift

  # Create archive/
  pkg_root=${dir}-${version}
  mv $dir $pkg_root
  tar -Jcf /opt/rootfs/output/$pkg_root.tar.xz $pkg_root &
}

[ $BUSYBOX_ENABLED ] && package_dir "busybox-rootfs"
[ $BUILDROOT_ENABLED ] && package_dir "buildroot-qemu-rootfs"
[ $BUILDROOT_ENABLED ] && package_dir "buildroot-litex-rootfs"
wait

