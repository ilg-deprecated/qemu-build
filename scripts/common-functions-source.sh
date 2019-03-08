# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the build scripts (both native
# and container).

# -----------------------------------------------------------------------------

function prepare_extras()
{
  # ---------------------------------------------------------------------------

  EXTRA_CPPFLAGS=""

  EXTRA_CFLAGS="-ffunction-sections -fdata-sections -pipe"
  EXTRA_CXXFLAGS="-ffunction-sections -fdata-sections -pipe"

  EXTRA_LDFLAGS_LIB=""
  EXTRA_LDFLAGS="${EXTRA_LDFLAGS_LIB}"
  EXTRA_LDFLAGS_APP=""

  if [ "${IS_DEBUG}" == "y" ]
  then
    EXTRA_CFLAGS+=" -g -O0"
    EXTRA_CXXFLAGS+=" -g -O0"
    EXTRA_LDFLAGS+=" -g -O0"
  else
    EXTRA_CFLAGS+=" -O2"
    EXTRA_CXXFLAGS+=" -O2"
    EXTRA_LDFLAGS+=" -O2"
  fi

  if [ "${TARGET_PLATFORM}" == "linux" ]
  then
    local which_gcc_7="$(xbb_activate; which "g++-7")"
    if [ ! -z "${which_gcc_7}" ]
    then
      export CC="gcc-7"
      export CXX="g++-7"
    else
      export CC="gcc"
      export CXX="g++"
    fi
    # Do not add -static here, it fails.
    # Do not try to link pthread statically, it must match the system glibc.
    EXTRA_LDFLAGS_APP="${EXTRA_LDFLAGS} -static-libstdc++ -Wl,--gc-sections"
  elif [ "${TARGET_PLATFORM}" == "darwin" ]
  then
    export CC="gcc-7"
    export CXX="g++-7"
    # Note: macOS linker ignores -static-libstdc++, so 
    # libstdc++.6.dylib should be handled.
    EXTRA_LDFLAGS_APP="${EXTRA_LDFLAGS} -Wl,-dead_strip"
  elif [ "${TARGET_PLATFORM}" == "win32" ]
  then
    # CRT_glob is from ARM script
    # -static avoids libwinpthread-1.dll 
    # -static-libgcc avoids libgcc_s_sjlj-1.dll 
    EXTRA_LDFLAGS_APP="${EXTRA_LDFLAGS} -static-libgcc -static-libstdc++ -Wl,--gc-sections"
  fi

  set +u
  if [ ! -z "${XBB_FOLDER}" -a -x "${XBB_FOLDER}"/bin/pkg-config-verbose ]
  then
    export PKG_CONFIG="${XBB_FOLDER}"/bin/pkg-config-verbose
  fi
  set -u

  PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-""}

  set +u
  echo
  echo "CC=${CC}"
  echo "CXX=${CXX}"
  echo "EXTRA_CPPFLAGS=${EXTRA_CPPFLAGS}"
  echo "EXTRA_CFLAGS=${EXTRA_CFLAGS}"
  echo "EXTRA_CXXFLAGS=${EXTRA_CXXFLAGS}"
  echo "EXTRA_LDFLAGS=${EXTRA_LDFLAGS}"

  echo "EXTRA_LDFLAGS_APP=${EXTRA_LDFLAGS_APP}"

  echo "PKG_CONFIG=${PKG_CONFIG}"
  set -u

  set +u
  if [ "${TARGET_PLATFORM}" == "win32" -a ! -z "${CC}" -a ! -z  "${CXX}" ]
  then
    echo "CC and CXX must not be set for cross builds."
    exit 1
  fi
  set -u

  HAS_NAME_ARCH=${HAS_NAME_ARCH:-""}

  # libtool fails with the Ubuntu /bin/sh.
  export SHELL="/bin/bash"
  export CONFIG_SHELL="/bin/bash"
}

# -----------------------------------------------------------------------------

function download_qemu() 
{
  if [ ! -d "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}" ]
  then
    (
      xbb_activate

      cd "${WORK_FOLDER_PATH}"
      git_clone "${QEMU_GIT_URL}" "${QEMU_GIT_BRANCH}" \
          "${QEMU_GIT_COMMIT}" "${QEMU_SRC_FOLDER_NAME}"
      cd "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"

      # git submodule update --init --recursive --remote
      # Do not bring all submodules; for better control,
      # prefer to build separate pixman. 
      git submodule update --init dtc

      rm -rf pixman roms

      local patch_file="${WORK_FOLDER_PATH}/build.git/patches/qemu-${RELEASE_VERSION}.git-patch"
      if [ -f "${patch_file}" ]
      then
        git apply "${patch_file}"
      fi
    )
  fi
}

function do_actions()
{
  if [ "${ACTION}" == "clean" ]
  then
    echo

    if [ "${IS_NATIVE}" == "y" ]
    then
      echo "Removing the ${TARGET_FOLDER_NAME} build and install qemu folders..."

      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}/build/${APP_LC_NAME}"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}/install/${APP_LC_NAME}"
    elif [ ! -z "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_LINUX32}${DO_BUILD_LINUX64}${DO_BUILD_OSX}" ]
    then
      if [ "${DO_BUILD_WIN32}" == "y" ]
      then
        echo "Removing the win32-x32 build and install qemu folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32/build/${APP_LC_NAME}"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32/install/${APP_LC_NAME}"
      fi
      if [ "${DO_BUILD_WIN64}" == "y" ]
      then
        echo "Removing the win32-x64 build and install qemu folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64/build/${APP_LC_NAME}"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64/install/${APP_LC_NAME}"
      fi
      if [ "${DO_BUILD_LINUX32}" == "y" ]
      then
        echo "Removing the linux-x32 build and install qemu folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32/build/${APP_LC_NAME}"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32/install/${APP_LC_NAME}"
      fi
      if [ "${DO_BUILD_LINUX64}" == "y" ]
      then
        echo "Removing the linux-x64 build and install qemu folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64/build/${APP_LC_NAME}"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64/install/${APP_LC_NAME}"
      fi
      if [ "${DO_BUILD_OSX}" == "y" ]
      then
        echo "Removing the darwin-x64 build and install qemu folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64/build/${APP_LC_NAME}"
        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64/install/${APP_LC_NAME}"
      fi
    else
      echo "Removing the ${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH} build and install qemu folders..."

      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}/build/${APP_LC_NAME}"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}/install/${APP_LC_NAME}"
    fi
  fi

  if [ "${ACTION}" == "cleanlibs" ]
  then
    echo

    if [ "${IS_NATIVE}" == "y" ]
    then
      echo "Removing the ${TARGET_FOLDER_NAME} build and install libs folders..."

      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}/build/libs"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}/install/libs"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}/install"/stamp-*-installed
    elif [ ! -z "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_LINUX32}${DO_BUILD_LINUX64}${DO_BUILD_OSX}" ]
    then
      if [ "${DO_BUILD_WIN32}" == "y" ]
      then
        echo "Removing the win32-x32 build and install libs folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32/build/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32/install/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32/install"/stamp-*-installed
      fi
      if [ "${DO_BUILD_WIN64}" == "y" ]
      then
        echo "Removing the win32-x64 build and install libs folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64/build/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64/install/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64/install"/stamp-*-installed
      fi
      if [ "${DO_BUILD_LINUX32}" == "y" ]
      then
        echo "Removing the linux-x32 build and install libs folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32/build/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32/install/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32/install"/stamp-*-installed
      fi
      if [ "${DO_BUILD_LINUX64}" == "y" ]
      then
        echo "Removing the linux-x64 build and install libs folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64/build/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64/install/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64/install"/stamp-*-installed
      fi
      if [ "${DO_BUILD_OSX}" == "y" ]
      then
        echo "Removing the darwin-x64 build and install libs folders..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64/build/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64/install/libs"
        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64/install"/stamp-*-installed
      fi
    else
      echo "Removing the ${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH} build and install libs folders..."

      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}/build/libs"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}/install/libs"
      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}/install"/stamp-*-installed
    fi
  fi

  if [ "${ACTION}" == "cleanall" ]
  then
    echo
    if [ "${IS_NATIVE}" == "y" ]
    then
      echo "Removing the ${TARGET_FOLDER_NAME} folder..."
  
      rm -rf "${HOST_WORK_FOLDER_PATH}/${TARGET_FOLDER_NAME}"
    elif [ ! -z "${DO_BUILD_WIN32}${DO_BUILD_WIN64}${DO_BUILD_LINUX32}${DO_BUILD_LINUX64}${DO_BUILD_OSX}" ]
    then
      if [ "${DO_BUILD_WIN32}" == "y" ]
      then
        echo "Removing the win32-x32 folder..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x32"
      fi
      if [ "${DO_BUILD_WIN64}" == "y" ]
      then
        echo "Removing the win32-x64 folder..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/win32-x64"
      fi
      if [ "${DO_BUILD_LINUX32}" == "y" ]
      then
        echo "Removing the linux-x32 folder..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x32"
      fi
      if [ "${DO_BUILD_LINUX64}" == "y" ]
      then
        echo "Removing the linux-x64 folder..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/linux-x64"
      fi
      if [ "${DO_BUILD_OSX}" == "y" ]
      then
        echo "Removing the darwin-x64 folder..."

        rm -rf "${HOST_WORK_FOLDER_PATH}/darwin-x64"
      fi
    else
      echo "Removing the ${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH} folder..."

      rm -rf "${HOST_WORK_FOLDER_PATH}/${HOST_NODE_PLATFORM}-${HOST_NODE_ARCH}"
    fi
  fi

  if [ "${ACTION}" == "clean" -o "${ACTION}" == "cleanlibs" -o "${ACTION}" == "cleanall" ]
  then
    echo
    echo "Clean completed. Proceed with a regular build."

    exit 0
  fi

  # Not used for native buils. Otherwise the names of the docker images
  # must be set.
  if [ "${ACTION}" == "preload-images" ]
  then
    host_start_timer

    host_prepare_docker

    echo
    echo "Check/Preload Docker images..."

    echo
    docker run --interactive --tty "${docker_linux64_image}" \
      lsb_release --description --short

    echo
    docker run --interactive --tty "${docker_linux32_image}" \
      lsb_release --description --short

    echo
    docker images

    host_stop_timer

    exit 0
  fi
}

# -----------------------------------------------------------------------------
