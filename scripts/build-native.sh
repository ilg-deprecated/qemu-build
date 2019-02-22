#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------

# Script to build a native GNU MCU Eclipse ARM QEMU, which uses the
# tools and libraries available on the host machine. It is generally
# intended for development and creating customised versions (as opposed
# to the build intended for creating distribution packages).
#
# Developed on Ubuntu 18 LTS x64. 

# -----------------------------------------------------------------------------

ACTION=""

DO_BUILD_WIN=""
ENV_FILE=""

# Attempts to use 8 occasionally failed, reduce if necessary.
if [ "$(uname)" == "Darwin" ]
then
  JOBS="--jobs=$(sysctl -n hw.ncpu)"
else
  JOBS="--jobs=$(grep ^processor /proc/cpuinfo|wc -l)"
fi

while [ $# -gt 0 ]
do
  case "$1" in

    clean)
      ACTION="$1"
      ;;

    --win|--windows)
      DO_BUILD_WIN32="y"
      ;;

    --env-file)
      shift
      ENV_FILE="$1"
      ;;

    --jobs)
      shift
      JOBS="--jobs=$1"
      ;;

   --help)
      echo "Build a local/native GNU MCU Eclipse ARM QEMU."
      echo "Usage:"
      # Some of the options are processed by the container script.
      echo "    bash $0 [--win] [--env-file file] [--jobs N] [--help]"
      echo
      exit 1
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;

  esac
  shift

done

# -----------------------------------------------------------------------------
# Identify helper scripts.

build_script_path=$0
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path=$(pwd)/$0
fi

script_folder_path="$(dirname ${build_script_path})"
script_folder_name="$(basename ${script_folder_path})"

if [ -f "${script_folder_path}"/VERSION ]
then
  # When running from the distribution folder.
  RELEASE_VERSION=${RELEASE_VERSION:-"$(cat "${script_folder_path}"/VERSION)"}
fi

echo
echo "Processing release ${RELEASE_VERSION}..."

echo
defines_script_path="${script_folder_path}/defs-source.sh"
echo "Definitions source script: \"${defines_script_path}\"."
source "${defines_script_path}"

# The Work folder is in HOME.
HOST_WORK_FOLDER_PATH=${HOST_WORK_FOLDER_PATH:-"${HOME}/Work/${APP_LC_NAME}-${RELEASE_VERSION}-dev"}
mkdir -p "${HOST_WORK_FOLDER_PATH}"

WORK_FOLDER_PATH=${HOST_WORK_FOLDER_PATH}

# -----------------------------------------------------------------------------

if [ "${ACTION}" == "clean" ]
then
  # Remove most build and temporary folders.
  echo
  echo "Removing the build and include folders..."

  rm -rf "${HOST_WORK_FOLDER_PATH}"/build
  rm -rf "${HOST_WORK_FOLDER_PATH}"/install

  echo
  echo "Clean completed. Proceed with a regular build."

  exit 0
fi

# -----------------------------------------------------------------------------

host_functions_script_path="${script_folder_path}/helper/host-functions-source.sh"
echo "Host helper functions source script: \"${host_functions_script_path}\"."
source "${host_functions_script_path}"

common_helper_functions_script_path="${script_folder_path}/helper/common-functions-source.sh"
echo "Common helper functions source script: \"${common_helper_functions_script_path}\"."
source "${common_helper_functions_script_path}"

# May override some of the helper/common definitions.
common_functions_script_path="${script_folder_path}/common-functions-source.sh"
echo "Common functions source script: \"${common_functions_script_path}\"."
source "${common_functions_script_path}"

QEMU_PROJECT_NAME="qemu"
QEMU_VERSION="2.8"

QEMU_SRC_FOLDER_NAME=${QEMU_SRC_FOLDER_NAME:-"${QEMU_PROJECT_NAME}.git"}
QEMU_GIT_URL="https://github.com/gnu-mcu-eclipse/qemu.git"
QEMU_GIT_BRANCH=${QEMU_GIT_BRANCH:-"gnuarmeclipse"}
QEMU_GIT_COMMIT=${QEMU_GIT_COMMIT:-""}

# -----------------------------------------------------------------------------

# Copy the build files to the Work area, to make them available for the 
# container script.
rm -rf "${HOST_WORK_FOLDER_PATH}"/build.git
mkdir -p "${HOST_WORK_FOLDER_PATH}"/build.git
cp -r "$(dirname ${script_folder_path})"/* "${HOST_WORK_FOLDER_PATH}"/build.git
rm -rf "${HOST_WORK_FOLDER_PATH}"/build.git/scripts/helper/.git
rm -rf "${HOST_WORK_FOLDER_PATH}"/build.git/scripts/helper/build-helper.sh

# -----------------------------------------------------------------------------

# Set the DISTRIBUTION_FILE_DATE.
host_get_current_date

# -----------------------------------------------------------------------------

host_start_timer

host_detect

native_prepare_prerequisites

# -----------------------------------------------------------------------------

download_qemu

(
  mkdir -p "${BUILD_FOLDER_PATH}"
  cd "${BUILD_FOLDER_PATH}"

  xbb_activate

  export CFLAGS="${EXTRA_CFLAGS} -Wno-format-truncation -Wno-incompatible-pointer-types -Wno-unused-function -Wno-unused-but-set-variable -Wno-unused-result"
  export CPPFLAGS="${EXTRA_CPPFLAGS}"
  export LDFLAGS="${EXTRA_LDFLAGS_APP}"

  CROSS=""

  if [ ! -f "config.status" ]
  then

    echo
    echo "Running qemu configure..."

    # Although it shouldn't, the script checks python before --help.
    bash "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"/configure \
      --python=python2 \
      --help

    # --static fails due to sdl2.
    bash ${DEBUG} "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"/configure \
      --prefix="${APP_PREFIX}" \
      ${CROSS} \
      --extra-cflags="${CFLAGS} ${CPPFLAGS}" \
      --extra-ldflags="${LDFLAGS}" \
      --disable-werror \
      --target-list="gnuarmeclipse-softmmu" \
      \
      --enable-debug \
      --disable-linux-aio \
      --disable-libnfs \
      --disable-snappy \
      --disable-libssh2 \
      --disable-gnutls \
      --disable-nettle \
      --disable-lzo \
      --disable-seccomp \
      --disable-bluez \
      --disable-gcrypt \
      \
      --bindir="${APP_PREFIX}"/bin \
      --docdir="${APP_PREFIX_DOC}" \
      --mandir="${APP_PREFIX_DOC}"/man \
      \
      --with-sdlabi="2.0" \
      --python=python2 \

  fi

  echo
  echo "Running qemu make..."

  make ${JOBS}
  make install
  make install-gme

  if [ "${TARGET_OS}" != "win" ]
  then
    echo
    "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse --version
  fi

  if [ "${TARGET_OS}" == "linux" ]
  then
    echo
    echo "Shared libraries:"
    readelf -d "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse | grep 'Shared library:'
  fi
)

# copy_extra

# -----------------------------------------------------------------------------

host_stop_timer

# Completed successfully.
exit 0

# -----------------------------------------------------------------------------
