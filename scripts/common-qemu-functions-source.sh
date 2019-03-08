# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the build scripts (both native
# and container).

# -----------------------------------------------------------------------------


function do_qemu() 
{
  (
    xbb_activate
    download_qemu
  )

  (
    mkdir -p "${APP_BUILD_FOLDER_PATH}"
    cd "${APP_BUILD_FOLDER_PATH}"

    xbb_activate
    xbb_activate_this

    export CFLAGS="${EXTRA_CFLAGS} -Wno-format-truncation -Wno-incompatible-pointer-types -Wno-unused-function -Wno-unused-but-set-variable -Wno-unused-result"

    export CPPFLAGS="${EXTRA_CPPFLAGS}"
    if [ "${IS_DEBUG}" == "y" ]
    then 
      export CPPFLAGS+=" -DDEBUG"
    fi

    export LDFLAGS="${EXTRA_LDFLAGS_APP}"

    if [ "${TARGET_PLATFORM}" == "win32" ]
    then
      CROSS="--cross-prefix=${CROSS_COMPILE_PREFIX}-"
    else
      CROSS=""
    fi

    (
      if [ ! -f "config.status" ]
      then

        echo
        echo "Overriding version..."
        cp -v "${BUILD_GIT_PATH}/scripts/VERSION" "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"

        echo
        echo "Running qemu configure..."

        # Although it shouldn't, the script checks python before --help.
        bash "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}/configure" \
          --python=python2 \
          --help

        if [ "${IS_DEBUG}" == "y" ]
        then 
          ENABLE_DEBUG="--enable-debug"
        else
          ENABLE_DEBUG=""
        fi

        # --static fails
        # ERROR: "gcc-7" cannot build an executable (is your linker broken?)
        bash ${DEBUG} "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}/configure" \
          --prefix="${APP_PREFIX}" \
          ${CROSS} \
          --extra-cflags="${CFLAGS} ${CPPFLAGS}" \
          --extra-ldflags="${LDFLAGS}" \
          --disable-werror \
          --target-list="gnuarmeclipse-softmmu" \
          \
          ${ENABLE_DEBUG} \
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
          --bindir="${APP_PREFIX}/bin" \
          --docdir="${APP_PREFIX_DOC}" \
          --mandir="${APP_PREFIX_DOC}/man" \
          \
          --with-sdlabi="2.0" \
          --python=python2 \

      fi
      cp "config.log" "${INSTALL_FOLDER_PATH}/configure-qemu-log.txt"
    ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/configure-qemu-output.txt"

    (
      echo
      echo "Running qemu make..."

      make ${JOBS}
      make install
      make install-gme

      if [ "${TARGET_PLATFORM}" == "linux" ]
      then
        echo
        echo "Shared libraries:"
        readelf -d "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" | grep 'Shared library:'

        # For just in case, normally must be done by the make file.
        strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"  || true

        if [ "${IS_DEVELOP}" != "y" ]
        then
          echo
          echo "Preparing libraries..."
          patch_linux_elf_origin "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse 

          copy_linux_user_so libSDL2-2.0
          copy_linux_user_so libSDL2_image-2.0
          copy_linux_user_so libgthread-2.0
          copy_linux_user_so libglib-2.0
          copy_linux_user_so libpixman-1
          copy_linux_user_so libz
          copy_linux_user_so libiconv
          copy_linux_user_so libpng16
          copy_linux_user_so libjpeg

          copy_linux_system_so libstdc++
          copy_linux_system_so libgcc_s
        fi

        echo
        "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" --version
      elif [ "${TARGET_PLATFORM}" == "darwin" ]
      then
        echo
        echo "Dynamic libraries:"
        otool -L "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"

        # For just in case, normally must be done by the make file.
        strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" || true

        if [ "${IS_DEVELOP}" != "y" ]
        then
          echo
          echo "Preparing libraries..."
          change_dylib "libz.1.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libpixman-1.0.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libSDL2-2.0.0.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libSDL2_image-2.0.0.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libgthread-2.0.0.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libglib-2.0.0.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libintl.8.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          # change_dylib "libiconv.2.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libstdc++.6.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse
          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse

          otool -L "${APP_PREFIX}"/bin/*.dylib

          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libstdc++.6.dylib

          change_dylib "libSDL2-2.0.0.dylib" "${APP_PREFIX}"/bin/libSDL2_image-2.0.0.dylib
          # change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libSDL2_image-2.0.0.dylib

          change_dylib "libglib-2.0.0.dylib" "${APP_PREFIX}"/bin/libgthread-2.0.0.dylib

          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libpixman-1.0.dylib

          change_dylib "libiconv.2.dylib" "${APP_PREFIX}"/bin/libglib-2.0.0.dylib
          change_dylib "libintl.8.dylib" "${APP_PREFIX}"/bin/libglib-2.0.0.dylib

          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libiconv.2.dylib

          change_dylib "libiconv.2.dylib" "${APP_PREFIX}"/bin/libintl.8.dylib
          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libintl.8.dylib

          change_dylib "libiconv.2.dylib" "${APP_PREFIX}"/bin/libgthread-2.0.0.dylib
          change_dylib "libintl.8.dylib" "${APP_PREFIX}"/bin/libgthread-2.0.0.dylib

          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libz.1.dylib
        fi

        echo
        "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" --version
      elif [ "${TARGET_PLATFORM}" == "win32" ]
      then
        echo
        echo "Dynamic libraries:"
        echo "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe"
        echo qemu-system-gnuarmeclipse.exe
        ${CROSS_COMPILE_PREFIX}-objdump -x "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" | grep -i 'DLL Name'

        # For just in case, normally must be done by the make file.
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" || true

        rm -f "${APP_PREFIX}/bin/qemu-system-gnuarmeclipsew.exe"

        # Windows needs all DLLs in this folder, even for development builds.
        echo
        echo "Copying all compiled DLLs"
        cp -v "${LIBS_INSTALL_FOLDER_PATH}/bin/"*.dll "${APP_PREFIX}/bin"

        # Copy libssp-0.dll (Stack smashing protection).
        copy_win_gcc_dll libssp-0.dll

        if [ "${TARGET_ARCH}" == "x32" ]
        then
          copy_win_gcc_dll "libgcc_s_sjlj-1.dll"
        elif [ "${TARGET_ARCH}" == "x64" ]
        then
          copy_win_gcc_dll "libgcc_s_seh-1.dll"
        fi

        local dlls=$(find ${APP_PREFIX} -name \*.dll)
        for dll in ${dlls}
        do
          echo "$(basename "${dll}")"
          ${CROSS_COMPILE_PREFIX}-objdump -x "${dll}" | grep -i 'DLL Name'
        done

        local binaries=$(find ${APP_PREFIX} -name \*.exe)
        for bin in ${binaries}
        do
          check_binary "${bin}"
        done

        local wsl_path=$(which wsl.exe)
        if [ ! -z "${wsl_path}" ]
        then
          echo
          "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" --version
        else 
          local wine_path=$(which wine)
          if [ ! -z "${wine_path}" ]
          then
            echo
            wine "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" --version
          else
            echo
            echo "Install wine if you want to run the .exe binaries on Linux."
          fi
        fi
      fi

      if [ "${IS_DEVELOP}" != "y" ]
      then
        strip_binaries
        check_binaries
      fi

    ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/make-qemu-output.txt"
  )
}

function strip_binaries()
{
  if [ "${WITH_STRIP}" == "y" ]
  then
    (
      xbb_activate

      echo
      echo "Striping binaries..."

      if [ "${TARGET_PLATFORM}" == "win32" ]
      then
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" || true
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/"*.dll || true
      else
        strip "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse || true
      fi
    )
  fi
}

function check_binaries()
{
  if [ "${TARGET_PLATFORM}" == "win32" ]
  then

    echo
    echo "Checking binaries for unwanted DLLs..."

    check_binary "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe"

    local libs=$(find "${APP_PREFIX}"/bin -name \*.dll -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  elif [ "${TARGET_PLATFORM}" == "darwin" ]
  then

    echo
    echo "Checking binaries for unwanted dynamic libraries..."

    check_binary "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"

    local libs=$(find "${APP_PREFIX}"/bin -name \*.dylib -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  elif [ "${TARGET_PLATFORM}" == "linux" ]
  then

    echo
    echo "Checking binaries for unwanted shared libraries..."

    check_binary "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"

    local libs=$(find "${APP_PREFIX}"/bin -name \*.so.\* -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  else

    echo "Unsupported TARGET_PLATFORM ${TARGET_PLATFORM}"
    exit 1

  fi
}

function copy_gme_files()
{
  rm -rf "${APP_PREFIX}/${DISTRO_LC_NAME}"
  mkdir -p "${APP_PREFIX}/${DISTRO_LC_NAME}"

  echo
  echo "Copying license files..."

  copy_license \
    "${SOURCES_FOLDER_PATH}/${ZLIB_SRC_FOLDER_NAME}" \
    "${ZLIB_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBPNG_SRC_FOLDER_NAME}" \
    "${LIBPNG_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${JPEG_SRC_FOLDER_NAME}" \
    "${JPEG_FOLDER_NAME}"
    
  copy_license \
    "${SOURCES_FOLDER_PATH}/${SDL2_SRC_FOLDER_NAME}" \
    "${SDL2_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${SDL2_IMAGE_SRC_FOLDER_NAME}" \
    "${SDL2_IMAGE_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBFFI_SRC_FOLDER_NAME}" \
    "${LIBFFI_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${LIBICONV_SRC_FOLDER_NAME}" \
    "${LIBICONV_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${GETTEXT_SRC_FOLDER_NAME}" \
    "${GETTEXT_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${GLIB_SRC_FOLDER_NAME}" \
    "${GLIB_FOLDER_NAME}"

  copy_license \
    "${SOURCES_FOLDER_PATH}/${PIXMAN_SRC_FOLDER_NAME}" \
    "${PIXMAN_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}" \
    "${QEMU_FOLDER_NAME}"

  copy_build_files

  echo
  echo "Copying GME files..."

  cd "${WORK_FOLDER_PATH}/build.git"
  /usr/bin/install -v -c -m 644 "${README_OUT_FILE_NAME}" \
    "${APP_PREFIX}/README.md"
}


