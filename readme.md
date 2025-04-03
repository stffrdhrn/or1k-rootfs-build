# OpenRISC rootfs build and release scripts

This project contains a set of scripts and docker images for building rootfs
images for the OpenRISC platform.  Once the builds are done we upload release
artifacts to [github](https://github.com/openrisc/or1k-rootfs-build/releases).

If you are not a release maintainer you probably don't need this.  You can get
binaries from our release page mentioned above.

## Building the toolchain

First build the docker image.  This will setup a sandboxed docker image which
will run builds for OpenRISC buildroot and busybox rootfs images.

```
docker build -t or1k-rootfs-build or1k-rootfs-build/
```

Running the build, binaries will be outputted the `/opt/rootfs/output` volume.  You
can choose versions of BUILDROOT and BUSYBOX.

```
# The location where you have tarballs, so they dont need to be
# downloaded every time you build
CACHEDIR=$HOME/work/docker/volumes/rootfs/cache
# The location where you want your output to go
OUTPUTDIR=/home/shorne/work/docker/rootfs/output

docker run -it --rm \
  -e BUILDROOT_ENABLED=1 \
  -e BUSYBOX_ENABLED=1 \
  -e TEST_ENABLED=1 \
  -e CROSSTOOL=or1k-none-linux-musl- \
  -e CROSSTOOL_VERSION=or1k-14.2.0-20250329 \
  -e BUILDROOT_VERSION=2025.02 \
  -e BUSYBOX_VERSION=1.37.0 \
  -e QEMU_VERSION=9.2.2 \
  -e LINUX_VERSION=v6.14 \
  -v ${OUTPUTDIR}:/opt/rootfs/output:Z \
  -v ${CACHEDIR}:/opt/rootfs/cache:Z \
  or1k-toolchain-build
```

## Environment Parameters

You can change the build behavior without rebuilding your docker image by
passing in different environment veriables.  These can be used to change
package versions or enable and disable features.

### Disabling Builds

You can disable builds by undefining any of these variables, by default all
builds are enabled.
 - `BUILDROOT_ENABLED` - (default `1`) enable/disable the buildroot build
 - `BUSYBOX_ENABLED` - (default `1`) enable/disable the busybox build

### Changing Versions

The source versions of components pulled into the toolchain can be adjusted.

 - `BUILDROOT_VERSION` - (default `2025.02`) version downloaded from: https://buildroot.org/downloads
 - `BUSYBOX_VERSION` - (default `1.37.0`) version downloaded from: https://busybox.net/downloads

### Misc Parameters

 - `TEST_ENABLED` - (default `1`) enable/disable linux boot tesing of rootfs images
   and saving output to the `/opt/rootfs/output` output volume.
 - `CROSSTOOL` - (default `or1k-none-linux-musl-`) the cross compiler prefix for the
   toolchain used for building busybox and linux test kernels.
 - `CROSSTOOL_VERSION` - (default `or1k-14.2.0-20250329`) the version of the toolchain
   we support booth bootlin and our own toolchains.
    - For version prefix `or1k-buildroot-*` toolchains are downloaded from: https://toolchains.bootlin.com/downloads/releases/toolchains/openrisc/tarballs/
    - For version prefix `or1k-*` toolchains are downloaded from: https://github.com/openrisc/or1k-toolchain-build/releases/download

## Choosing versions

This tool is used for creating stable releases, at the moment we manually track stable
releases and make releases periodically.  Watch for new releases for each project at:

 * [Buildroot](https://buildroot.org/download.html) - Released 4 times a year.
 * [Busybox](https://busybox.net/) - Released about once a year.
 * [Linux Kernel](https://kernel.org) - Used for testing we don't need to update too often.
 * [QEMU](https://www.qemu.org) - Periodically released, used for running tests not part of toolchain.

## Signing your work

When you are done you may want to sign your tarball archives. You can do
something like the following.

```
# Sign tar
gpg --output or1k-linux-musl-5.4.0-20170202.tar.sign --detach-sign or1k-linux-musl-5.4.0-20170202.tar

# Create clearsigned dir listing
sha256sum or1k-linux-musl-5.4.0-20170202.tar* | gpg --output sha256sums.asc --clearsign
```

## Uploading a release

This is specifically for OpenRISC maintainers.  The scripts in `github/` can
be used to create a release and upload all of the binary artifacts to github.

First setups a `~/.github.api` with a github api token defined in
`github_token`. i.e.

```
# Github api file for the curl release utilities
github_token=TOKEN
```

Next create a release

```
./github/release.sh
```

Then upload your binaries, it will automatically upload to the last release
you built.

```
./github/upload.sh ../volume/rootfs/output/*.tar.*
```
