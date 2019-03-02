function do_native_qemu() 
{
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

      if [ "${IS_DEBUG}" != "y" ]
      then
        # For just in case, normally must be done by the make file.
        strip "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"
      fi

      if [ "${TARGET_PLATFORM}" != "win32" ]
      then
        echo
        "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" --version
      fi

      if [ "${TARGET_PLATFORM}" == "linux" ]
      then
        echo
        echo "Shared libraries:"
        readelf -d "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" | grep 'Shared library:'
      elif [ "${TARGET_PLATFORM}" == "darwin" ]
      then
        echo
        echo "Dynamic libraries:"
        otool -L "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"
      elif [ "${TARGET_PLATFORM}" == "win32" ]
      then
        echo
        echo "Dynamic libraries:"
        echo "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe"
        ${CROSS_COMPILE_PREFIX}-objdump -x "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse.exe" | grep -i 'DLL Name'

        echo
        echo "Copying all compiled DLLs"
        cp -v "${LIBS_INSTALL_FOLDER_PATH}/bin/"*.dll "${APP_PREFIX}/bin"

        # Version looks like '7.3-win32'.
        local gcc_version=$(${CROSS_COMPILE_PREFIX}-gcc --version | grep gcc | sed -e 's/.*\s\([0-9]*\)[.]\([0-9]*\)[-]\([0-9a-zA-Z]*\).*/\1.\2-\3/')

        # Copy .../7.3-win32/libssp-0.dll (Stack smashing protection).
        cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${gcc_version}/libssp-0.dll" "${APP_PREFIX}/bin"

        if [ "${TARGET_ARCH}" == "x32" ]
        then
          # copy_win_gcc_dll "libgcc_s_sjlj-1.dll"
          cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${gcc_version}/libgcc_s_sjlj-1.dll" "${APP_PREFIX}/bin"
        elif [ "${TARGET_ARCH}" == "x64" ]
        then
          # copy_win_gcc_dll "libgcc_s_seh-1.dll"
          cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${gcc_version}/libgcc_s_seh-1.dll" "${APP_PREFIX}/bin"
        fi

        local binaries=$(find ${APP_PREFIX} -name \*.exe)
        for bin in ${binaries}
        do
          check_binary "${bin}"
        done
      fi
    ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/make-qemu-output.txt"
  )
}
