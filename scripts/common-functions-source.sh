# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the build scripts (both native
# and container).

# -----------------------------------------------------------------------------

function native_prepare_prerequisites()
{
  if [ -f "/opt/xbb/xbb-source.sh" ]
  then
    source "/opt/xbb/xbb-source.sh"
  fi

  TARGET_OS="$(uname | tr '[:upper:]' '[:lower:]')"
  TARGET_BITS="${HOST_BITS}"

  # TARGET_FOLDER_NAME="${TARGET_OS}${TARGET_BITS}"

  BUILD_FOLDER_PATH="${WORK_FOLDER_PATH}/build"
  INSTALL_FOLDER_PATH="${WORK_FOLDER_PATH}/install"
  
  APP_PREFIX="${INSTALL_FOLDER_PATH}"
  APP_PREFIX_DOC="${APP_PREFIX}"/doc

  # ---------------------------------------------------------------------------


  EXTRA_CPPFLAGS=""

  EXTRA_CFLAGS="-ffunction-sections -fdata-sections -pipe"
  EXTRA_CXXFLAGS="-ffunction-sections -fdata-sections -pipe"

  EXTRA_CFLAGS+=" -g -O0"
  EXTRA_CXXFLAGS+=" -g -O0"

  EXTRA_LDFLAGS_LIB=""
  EXTRA_LDFLAGS="${EXTRA_LDFLAGS_LIB}"

  EXTRA_LDFLAGS+=" -g -O0"

  export CC="gcc"
  export CXX="g++"

  if [ "${TARGET_OS}" == "macos" ]
  then
    # Note: macOS linker ignores -static-libstdc++, so 
    # libstdc++.6.dylib should be handled.
    EXTRA_LDFLAGS_APP="${EXTRA_LDFLAGS} -Wl,-dead_strip"
  elif [ "${TARGET_OS}" == "linux" ]
  then
    if [ ! -z "$(which "g++-7")" ]
    then
      export CC="gcc-7"
      export CXX="g++-7"
    fi
    # Do not add -static here, it fails.
    # Do not try to link pthread statically, it must match the system glibc.
    EXTRA_LDFLAGS_APP+="${EXTRA_LDFLAGS} -static-libstdc++ -Wl,--gc-sections"
  elif [ "${TARGET_OS}" == "win" ]
  then
    # CRT_glob is from ARM script
    # -static avoids libwinpthread-1.dll 
    # -static-libgcc avoids libgcc_s_sjlj-1.dll 
    EXTRA_LDFLAGS_APP+="${EXTRA_LDFLAGS} -static -static-libgcc -static-libstdc++ -Wl,--gc-sections"
  fi

  export PKG_CONFIG=pkg-config-verbose
  if [ "${TARGET_OS}" == "linux" -a "${TARGET_BITS}" == "64" ]
  then
    export PKG_CONFIG_LIBDIR=/usr/lib/x86_64-linux-gnu/pkgconfig:"${INSTALL_FOLDER_PATH}"/lib/pkgconfig
  fi

  if [[ ! -v PKG_CONFIG_PATH ]]
  then
    if [ -d "/usr/lib/pkgconfig" ]
    then
      export PKG_CONFIG_PATH="/usr/lib/pkgconfig"
    fi
  fi
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

      local patch_file="${WORK_FOLDER_PATH}"/build.git/patches/qemu-${RELEASE_VERSION}.git-patch
      if [ -f "${patch_file}" ]
      then
        git apply "${patch_file}"
      fi

      # cp "${WORK_FOLDER_PATH}"/build.git/scripts/VERSION .
    )
  fi
}

# Default empty definition, if XBB is available, it should
# redefine it.
function xbb_activate()
{
  :
}

# -----------------------------------------------------------------------------
