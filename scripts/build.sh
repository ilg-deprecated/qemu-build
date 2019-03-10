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
# Identify the script location, to reach, for example, the helper scripts.

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# Script to build the GNU MCU Eclipse ARM QEMU distribution packages.
#
# Developed on macOS 10.13 High Sierra, but intended to run on
# macOS 10.10 Yosemite and CentOS 6 XBB. 

# -----------------------------------------------------------------------------

echo
echo "GNU MCU Eclipse QEMU distribution build script."

echo
host_functions_script_path="${script_folder_path}/helper/host-functions-source.sh"
echo "Host helper functions source script: \"${host_functions_script_path}\"."
source "${host_functions_script_path}"

host_detect

# -----------------------------------------------------------------------------

host_options "    bash $0 [--win32] [--win64] [--linux32] [--linux64] [--osx] [--all] [clean|cleanlibs|cleanall|preload-images] [--env-file file] [--date YYYYmmdd-HHMM] [--disable-strip] [--without-pdf] [--with-html] [--develop] [--debug] [--jobs N] [--help]" $@

host_common

# -----------------------------------------------------------------------------

if [ -n "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_LINUX32}${DO_BUILD_LINUX64}" ]
then
  host_prepare_docker
fi

# ----- Build the native distribution. ----------------------------------------

if [ -z "${DO_BUILD_ANY}" ]
then

  host_build_target "Creating the native distribution..." \
    --script "${HOST_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
    --env-file "${ENV_FILE}" \
    -- \
    ${rest[@]-}

else

  # ----- Build the OS X distribution. ----------------------------------------

  if [ "${DO_BUILD_OSX}" == "y" ]
  then
    if [ "${HOST_UNAME}" == "Darwin" ]
    then
      host_build_target "Creating the OS X distribution..." \
        --script "${HOST_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
        --env-file "${ENV_FILE}" \
        --target-platform "darwin" \
        -- \
        ${rest[@]-}
    else
      echo "Building the macOS image is not possible on this platform."
      exit 1
    fi
  fi

  # ----- Build the GNU/Linux 64-bit distribution. ---------------------------

  if [ "${DO_BUILD_LINUX64}" == "y" ]
  then
    host_build_target "Creating the GNU/Linux 64-bit distribution..." \
      --script "${CONTAINER_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
      --env-file "${ENV_FILE}" \
      --target-platform "linux" \
      --target-arch "x64" \
      --target-bits 64 \
      --docker-image "${docker_linux64_image}" \
      -- \
      ${rest[@]-}
  fi

  # ----- Build the Windows 64-bit distribution. -----------------------------

  if [ "${DO_BUILD_WIN64}" == "y" ]
  then
    host_build_target "Creating the Windows 64-bit distribution..." \
      --script "${CONTAINER_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
      --env-file "${ENV_FILE}" \
      --target-platform "win32" \
      --target-arch "x64" \
      --target-bits 64 \
      --docker-image "${docker_linux64_image}" \
      -- \
      ${rest[@]-}
  fi

  # ----- Build the GNU/Linux 32-bit distribution. ---------------------------

  if [ "${DO_BUILD_LINUX32}" == "y" ]
  then
    host_build_target "Creating the GNU/Linux 32-bit distribution..." \
      --script "${CONTAINER_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
      --env-file "${ENV_FILE}" \
      --target-platform "linux" \
      --target-arch "x32" \
      --target-bits 32 \
      --docker-image "${docker_linux32_image}" \
      -- \
      ${rest[@]-}
  fi

  # ----- Build the Windows 32-bit distribution. -----------------------------

  # Since the actual container is a 32-bit, use the debian32 binaries.
  if [ "${DO_BUILD_WIN32}" == "y" ]
  then
    host_build_target "Creating the Windows 32-bit distribution..." \
      --script "${CONTAINER_WORK_FOLDER_PATH}/${CONTAINER_BUILD_SCRIPT_REL_PATH}" \
      --env-file "${ENV_FILE}" \
      --target-platform "win32" \
      --target-arch "x32" \
      --target-bits 32 \
      --docker-image "${docker_linux32_image}" \
      -- \
      ${rest[@]-}
  fi

fi

host_show_sha

# -----------------------------------------------------------------------------

host_stop_timer

host_notify_completed

echo
echo "Use --date ${DISTRIBUTION_FILE_DATE} if needed for a related build."

# Completed successfully.
exit 0

# -----------------------------------------------------------------------------
