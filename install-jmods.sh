#!/usr/bin/env bash
JMODS_JVM_DIR=${JAVA_HOME:-"/usr/lib/jvm/jdk"}/jmods/

JMODS_DOWNLOAD_DIR=${UNPACKED_ROOT:-"/tmp"}/jmods
JMODS_DOWNLOAD_URL=${JMODS_DOWNLOAD_URL:-"https://download.bell-sw.com/java/17.0.3.1+2/bellsoft-jdk17.0.3.1+2-linux-amd64-full.tar.gz"}
for JMOD in "$@"; do
  if [ ! -e "${JMODS_JVM_DIR}/$JMOD.jmod" ]; then
      printf "\n**** missing jmod %s. trying to install ****\n" "$JMOD"
      if [[ ! -d "${JMODS_JVM_DIR}" ]]; then
        mkdir "${JMODS_JVM_DIR}"
      fi
      if [ -e "${JMODS_CACHE}/$JMOD.jmod" ]; then
            cp -Rfv "${JMODS_CACHE}/$JMOD.jmod" "${JMODS_JVM_DIR}"
      else
        if [[ ! -d "${JMODS_DOWNLOAD_DIR}" ]]; then
                  printf "\n**** missing pre-loaded jmods. downloading defaults ****\n"
                  mkdir "${JMODS_DOWNLOAD_DIR}"
                  wget -O- "${JMODS_DOWNLOAD_URL}" | tar -xz -C "${JMODS_DOWNLOAD_DIR}" "*/jmods"
        fi
        cp -Rfv "${JMODS_DOWNLOAD_DIR}/$JMOD.jmod" "${JMODS_JVM_DIR}" || echo "$JMOD.jmod can't be found"
      fi
    fi
done
