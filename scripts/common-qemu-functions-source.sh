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

    CROSS=""

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
      fi
    ) 2>&1 | tee "${INSTALL_FOLDER_PATH}/make-qemu-output.txt"
  )
}
