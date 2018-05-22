# GNU MCU Eclipse QEMU - the build scripts

These are the scripts and additional files required to build the
[GNU MCU Eclipse QEMU](https://github.com/gnu-mcu-eclipse/qemu).

This release follows the official [QEMU](https://www.qemu.org).

The build scripts use the 
[xPack Build Box (XBB)](https://github.com/xpack/xpack-build-box), 
a set of elaborate build environments based on GCC 7.2 (Docker containers
for GNU/Linux and Windows or a custom HomeBrew for MacOS).

## Repository URLs

- the [GNU MCU Eclipse QEMU](https://github.com/gnu-mcu-eclipse/qemu) 
Git remote URL to clone from is https://github.com/gnu-mcu-eclipse/qemu.git
- the [QEMU](https://www.qemu.org) Git remote URL is
git://git.qemu.org/qemu.git

Add a remote named `qemu`, and pull the QEMU master → master.

## Changes

Compared to the original QEMU distribution, there are many additions. 

For details, see 
[The GNU MCU Eclipse QEMU](https://gnu-mcu-eclipse.github.io/qemu/) page.

## How to build

### Prerequisites

The prerequisites are common to all binary builds. Please follow the 
instructions in the separate 
[Prerequisites for building binaries](https://gnu-mcu-eclipse.github.io/developer/build-binaries-prerequisites-xbb/) 
page and return when ready.

### Download the build scripts repo

The build script is available from GitHub and can be 
[viewed online](https://github.com/gnu-mcu-eclipse/qemu-build/blob/master/scripts/build.sh).

To download it, clone the 
[gnu-mcu-eclipse/qemu-build](https://github.com/gnu-mcu-eclipse/qemu-build) 
Git repo, including submodules. 

```console
$ rm -rf ~/Downloads/qemu-build.git
$ git clone --recurse-submodules https://github.com/gnu-mcu-eclipse/qemu-build.git \
  ~/Downloads/qemu-build.git
```

### Check the script

The script creates a temporary build `Work/qemu-${version}` folder in 
the user home. Although not recommended, if for any reasons you need to 
change this, you can redefine `WORK_FOLDER_PATH` variable before invoking 
the script.

### Preload the Docker images

Docker does not require to explicitly download new images, but does this 
automatically at first use.

However, since the images used for this build are relatively large, it 
is recommended to load them explicitly before starting the build:

```console
$ bash ~/Downloads/qemu-build.git/scripts/build.sh preload-images
```

The result should look similar to:

```console
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ilegeul/centos32    6-xbb-v1            f695dd6cb46e        2 weeks ago         2.92GB
ilegeul/centos      6-xbb-v1            294dd5ee82f3        2 weeks ago         3.09GB
hello-world         latest              f2a91732366c        2 months ago        1.85kB
```

### Update git repos

To keep the development repository in sync with the original QEMU 
repository and the RISC-V repository:

- checkout `master`
- pull from `qemu/master`
- checkout `gnu-mcu-eclipse-dev`
- merge `master`
- add a tag like `v2.8.0-3-20180512` after each public release (mind the 
inner version `-3-`)

### Prepare release

To prepare a new release, first determine the QEMU version 
(like `2.8.0-3`) and update the `scripts/VERSION` file. The format is 
`2.8.0-3`. The fourth digit is the GNU MCU Eclipse release number 
of this version.

Add a new set of definitions in the `scripts/container-build.sh`, with 
the versions of various components.

### Update CHANGELOG.txt

Check `qemu-build.git/CHANGELOG.txt` and add the new release.

### Build

Although it is perfectly possible to build all binaries in a single step 
on a macOS system, due to Docker specifics, it is faster to build the 
GNU/Linux and Windows binaries on a GNU/Linux system and the macOS binary 
separately.

#### Build the GNU/Linux and Windows binaries

The current platform for GNU/Linux and Windows production builds is an 
Ubuntu 17.10 VirtualBox image running on a macMini with 16 GB of RAM 
and a fast SSD.

Before starting a multi-platform build, check if Docker is started:

```console
$ docker info
```

To build both the 32/64-bits Windows and GNU/Linux versions, use `--all`; 
to build selectively, use `--linux64 --win64` or `--linux32 --win32` 
(GNU/Linux can be built alone; Windows also requires the GNU/Linux build).

```console
$ bash ~/Downloads/qemu-build.git/scripts/build.sh --all
```

To build one of the previous versions:

```console
$ RELEASE_VERSION=0.10.0-8 bash ~/Downloads/qemu-build.git/scripts/build.sh --all
```

Several hours later, the output of the build script is a set of 4 files 
and their SHA signatures, created in the `deploy` folder:

```console
$ ls -l deploy
...
```

To copy the files from the build machine to the current development 
machine, open the `deploy` folder in a terminal and use `scp`:

```console
$ scp * ilg@ilg-mbp.local:Downloads
```

#### Build the macOS binary

The current platform for macOS production builds is a macOS 10.10.5 
VirtualBox image running on the same macMini with 16 GB of RAM and a 
fast SSD.

To build the latest macOS version, with the same timestamp as the 
previous build:

```console
$ caffeinate bash ~/Downloads/qemu-build.git/scripts/build.sh --osx --date YYYYMMDD-HHMM
```

To build one of the previous macOS versions:

```console
$ RELEASE_VERSION=0.10.0-8 caffeinate bash ~/Downloads/qemu-build.git/scripts/build.sh --osx --date YYYYMMDD-HHMM
```

For consistency reasons, the date should be the same as the GNU/Linux 
and Windows builds.

Several minutes later, the output of the build script is a compressed 
archive and its SHA signature, created in the `deploy` folder:

```console
$ ls -l deploy
...
```

To copy the files from the build machine to the current development 
machine, open the `deploy` folder in a terminal and use `scp`:

```console
$ scp * ilg@ilg-mbp.local:Downloads
```

### Subsequent runs

#### Separate platform specific builds

Instead of `--all`, you can use any combination of:

```
--win32 --win64 --linux32 --linux64
```

Please note that, due to the specifics of the GCC build process, the 
Windows build requires the corresponding GNU/Linux build, so `--win32` 
alone is equivalent to `--linux32 --win32` and `--win64` alone is 
equivalent to `--linux64 --win64`.

#### clean

To remove most build files, use:

```console
$ bash ~/Downloads/qemu-build.git/scripts/build.sh clean
```

To also remove the repository and the output files, use:

```console
$ bash ~/Downloads/qemu-build.git/scripts/build.sh cleanall
```

For production builds it is recommended to completely remove the build folder.

#### --develop

For performance reasons, the actual build folders are internal to each 
Docker run, and are not persistent. This gives the best speed, but has 
the disadvantage that interrupted builds cannot be resumed.

For development builds, it is possible to define the build folders in 
the host file system, and resume an interrupted build.

#### --debug

For development builds, it is also possible to create everything with 
`-g -O0` and be able to run debug sessions.

#### Interrupted builds

The Docker scripts run with root privileges. This is generally not a 
problem, since at the end of the script the output files are reassigned 
to the actual user.

However, for an interrupted build, this step is skipped, and files in 
the install folder will remain owned by root. Thus, before removing 
the build folder, it might be necessary to run a recursive `chown`.

## Install

The procedure to install GNU MCU Eclipse QEMU is platform specific, 
but relatively straight forward (a .zip archive on Windows, a compressed 
tar archive on macOS and GNU/Linux).

A portable method is to use [`xpm`](https://www.npmjs.com/package/xpm):

```console
$ xpm install --global @gnu-mcu-eclipse/qemu
```

More details are available on the [How to install the QEMU binaries?](https://gnu-mcu-eclipse.github.io/qemu/install/) page.

After install, the package should create a structure like this (only the 
first two depth levels are shown):

```console
$ tree -L 2 /Users/ilg/Library/xPacks/\@gnu-mcu-eclipse/qemu/xxxx/.content/
/Users/ilg/Library/xPacks/\@gnu-mcu-eclipse/qemu/xxxx/.content/
...
```

No other files are installed in any system folders or other locations.

## Uninstall

The binaries are distributed as portable archives; thus they do not need 
to run a setup and do not require an uninstall.


## Test

A simple test is performed by the script at the end, by launching the 
executable to check if all shared/dynamic libraries are correctly used.

For a true test you need to first install the package and then run the 
program from the final location. For example on macOS the output should 
look like:

```console
$ /Users/ilg/Library/xPacks/\@gnu-mcu-eclipse/qemu/xxxx/.content/bin/qemu --version
GNU MCU Eclipse 64-bits QEMU ...
```

## More build details

The build process is split into several scripts. The build starts on 
the host, with `build.sh`, which runs `container-build.sh` several 
times, once for each target, in one of the two docker containers. 
Both scripts include several other helper scripts. The entire process 
is quite complex, and an attempt to explain its functionality in a few 
words would not be realistic. Thus, the authoritative source of details 
remains the source code.
