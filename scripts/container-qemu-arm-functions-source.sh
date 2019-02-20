# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the container build scripts.

# -----------------------------------------------------------------------------

function do_qemu()
{

  local qemu_stamp_file_path="${INSTALL_FOLDER_PATH}"/stamp-qemu-installed

  if [ ! -f "${qemu_stamp_file_path}" ]
  then

    download_qemu

    (
      xbb_activate

      mkdir -p "${BUILD_FOLDER_PATH}/${QEMU_FOLDER_NAME}"
      cd "${BUILD_FOLDER_PATH}/${QEMU_FOLDER_NAME}"

      export CFLAGS="${EXTRA_CFLAGS} -Wno-format-truncation -Wno-incompatible-pointer-types -Wno-unused-function -Wno-unused-but-set-variable -Wno-unused-result"
      export CPPFLAGS="${EXTRA_CPPFLAGS}"
      export LDFLAGS="${EXTRA_LDFLAGS}"

      if [ ! -f "config.status" ]
      then

        echo
        echo "Running qemu configure..."
      
        local docdir
        if [ "${TARGET_OS}" == "win" ]
        then
          CROSS="--cross-prefix=${CROSS_COMPILE_PREFIX}-"
        elif [ "${TARGET_OS}" == "linux" ]
        then
          CROSS=""
        elif [ "${TARGET_OS}" == "macos" ]
        then
          CROSS=""
        fi

        (
          bash "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"/configure --help

          bash "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"/configure \
            --prefix="${APP_PREFIX}" \
            ${CROSS} \
            --extra-cflags="${CFLAGS} ${CPPFLAGS}" \
            --extra-ldflags="${LDFLAGS}" \
            --disable-werror \
            --target-list="gnuarmeclipse-softmmu" \
            \
            --bindir="${APP_PREFIX}"/bin \
            --docdir="${APP_PREFIX_DOC}" \
            --mandir="${APP_PREFIX_DOC}"/man \
            \
            --with-sdlabi="2.0" 

        ) 2>&1 | tee "${INSTALL_FOLDER_PATH}"/configure-qemu-output.txt
        cp "config.log" "${INSTALL_FOLDER_PATH}"/config-qemu-log.txt

      fi

      echo
      echo "Running qemu make..."
      
      (
        make ${JOBS}
        make install  
        make install-gme

        if [ "${WITH_PDF}" == "y" ]
        then
          make ${JOBS} 
          make install-pdf
        fi

        if [ "${WITH_HTML}" == "y" ]
        then
          make ${JOBS} 
          make install-html
        fi

        if [ "${TARGET_OS}" == "win" ]
        then

          rm -f "${APP_PREFIX}/bin/qemu-system-gnuarmeclipsew.exe"

          # Copy all compiled DLLs
          cp -v "${INSTALL_FOLDER_PATH}/bin/"*.dll "${APP_PREFIX}/bin"

          if [ "${TARGET_BITS}" == "32" ]
          then
            copy_win_gcc_dll "libgcc_s_sjlj-1.dll"
          elif [ "${TARGET_BITS}" == "64" ]
          then
            copy_win_gcc_dll "libgcc_s_seh-1.dll"
          fi

          copy_win_gcc_dll "libssp-0.dll"
          copy_win_gcc_dll "libstdc++-6.dll"

          copy_win_libwinpthread_dll

        elif [ "${TARGET_OS}" == "macos" ]
        then

          otool -L "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse

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
          change_dylib "libgcc_s.1.dylib" "${APP_PREFIX}"/bin/libSDL2_image-2.0.0.dylib

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

        elif [ "${TARGET_OS}" == "linux" ]
        then

          readelf -d "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse | egrep -i 'library|dynamic'

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

          readelf -d "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse | egrep -i 'library|dynamic'
          set +e
          find "${APP_PREFIX}"/bin -name '*.so*' -type f -exec readelf -d {} \; \
            | egrep -i 'library|dynamic'
          set -e
        fi

      ) 2>&1 | tee "${INSTALL_FOLDER_PATH}"/make-qemu-output.txt
    )

    strip_binaries
    check_binaries

    if [ "${TARGET_OS}" != "win" ]
    then
      echo
      "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse --version
    fi

    # Actually never stamp qemu, always run make.
    # touch "${qemu_stamp_file_path}"
  else
    echo "Component qemu already installed."
  fi
}

# -----------------------------------------------------------------------------

function copy_gme_files()
{
  rm -rf "${APP_PREFIX}/${DISTRO_LC_NAME}"
  mkdir -p "${APP_PREFIX}/${DISTRO_LC_NAME}"

  echo
  echo "Copying license files..."

  copy_license \
    "${WORK_FOLDER_PATH}/${ZLIB_SRC_FOLDER_NAME}" \
    "${ZLIB_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${LIBPNG_SRC_FOLDER_NAME}" \
    "${LIBPNG_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${JPEG_SRC_FOLDER_NAME}" \
    "${JPEG_FOLDER_NAME}"
    
  copy_license \
    "${WORK_FOLDER_PATH}/${SDL2_SRC_FOLDER_NAME}" \
    "${SDL2_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${SDL2_IMAGE_SRC_FOLDER_NAME}" \
    "${SDL2_IMAGE_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${LIBFFI_SRC_FOLDER_NAME}" \
    "${LIBFFI_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${LIBICONV_SRC_FOLDER_NAME}" \
    "${LIBICONV_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${GETTEXT_SRC_FOLDER_NAME}" \
    "${GETTEXT_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${GLIB_SRC_FOLDER_NAME}" \
    "${GLIB_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${PIXMAN_SRC_FOLDER_NAME}" \
    "${PIXMAN_FOLDER_NAME}"

  copy_license \
    "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}" \
    "${QEMU_FOLDER_NAME}"

  copy_build_files

  echo
  echo "Copying GME files..."

  cd "${WORK_FOLDER_PATH}"/build.git
  /usr/bin/install -v -c -m 644 "${README_OUT_FILE_NAME}" \
    "${APP_PREFIX}"/README.md
}

function strip_binaries()
{
  if [ "${WITH_STRIP}" == "y" ]
  then
    (
      xbb_activate

      echo
      echo "Striping binaries..."

      if [ "${TARGET_OS}" == "win" ]
      then
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe"
        ${CROSS_COMPILE_PREFIX}-strip "${APP_PREFIX}/bin/"*.dll
      else
        strip "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse || true
      fi
    )
  fi
}

function check_binaries()
{
  if [ "${TARGET_OS}" == "win" ]
  then

    echo
    echo "Checking binaries for unwanted DLLs..."

    check_binary "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse.exe

    local libs=$(find "${APP_PREFIX}"/bin -name \*.dll -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  elif [ "${TARGET_OS}" == "macos" ]
  then

    echo
    echo "Checking binaries for unwanted dynamic libraries..."

    check_binary "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse

    local libs=$(find "${APP_PREFIX}"/bin -name \*.dylib -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  elif [ "${TARGET_OS}" == "linux" ]
  then

    echo
    echo "Checking binaries for unwanted shared libraries..."

    check_binary "${APP_PREFIX}"/bin/qemu-system-gnuarmeclipse

    local libs=$(find "${APP_PREFIX}"/bin -name \*.so.\* -type f)
    for lib in ${libs} 
    do
      check_library ${lib}
    done

  else

    echo "Unsupported TARGET_OS ${TARGET_OS}"
    exit 1

  fi
}

