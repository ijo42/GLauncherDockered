# DOWNLOAD OR BUILD LAUNCHSERVER FILES

FROM bellsoft/liberica-openjdk-debian:17 as launcher-base

### Modify argument LAUNCHER_VERSION or redefine it via --build-arg parameter to have specific LaunchServer version installed:
###    docker build . --build-arg LAUNCHER_VERSION=v5.1.8
### Modify argument RUNTIME_VERSION  or redefine it via --build-arg parameter to have specific Runtime version installed:
###    docker build . --build-arg RUNTIME_VERSION=v1.4.0

ARG LAUNCHER_VERSION=master
ARG RUNTIME_VERSION=master
ARG GITHUB_REPO="GravitLauncher/Launcher"
ARG GITHUB_RUNTIME_REPO="GravitLauncher/LauncherRuntime"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update < /dev/null && apt-get install -qqy git < /dev/null && \
    mkdir -p /root/ls/launcher-modules /root/ls/runtime && set -e && \
    echo "Clone main repository" && \
    git clone -b dev https://github.com/${GITHUB_REPO}.git src && \
    cd src && \
    sed -i 's/git@github.com:/https:\/\/github.com\//' .gitmodules && \
    git checkout $LAUNCHER_VERSION && \
    git submodule sync && \
    git submodule update --init --recursive && \
    echo "Build" && \
    ./gradlew build || ( echo "Build failed. Stopping" && exit 101 ) && \
    PTH=LaunchServer/build/libs && \
    cp -R ${PTH}/LaunchServer.jar ${PTH}/launcher-libraries ${PTH}/launcher-libraries-compile ${PTH}/libraries /root/ls && \
    cd .. \
  && \
    echo "Clone runtime repository" && \
    git clone -b dev https://github.com/${GITHUB_RUNTIME_REPO}.git srcRuntime && \
    cd srcRuntime && \
    git checkout $RUNTIME_VERSION && \
    ./gradlew build || ( echo "Build failed. Stopping" && exit 102 ) && \
    cp $(echo build/libs/JavaRuntime-*.jar) /root/ls/launcher-modules/ && \
    cp -R runtime/* /root/ls/runtime/ && rm -rf $HOME/.gradle

# DOWNLOAD LIBERICA JDK

FROM lsiobase/alpine:3.14 as liberica

LABEL maintainer="ijo42 <admin@ijo42.ru>"

ARG OPT_PKGS="bash unzip"
ARG GLIBC_REPO=sgerrand/alpine-pkg-glibc
ARG GLIBC_VERSION=2.34-r0
ARG OPT_JMODS="java.base java.instrument jdk.management java.scripting java.sql jdk.unsupported java.naming java.desktop jdk.crypto.cryptoki jdk.crypto.ec javafx.base javafx.graphics javafx.controls"

### Modify argument LIBERICA_IMAGE_VARIANT or redefine it via --build-arg parameter to have specific liberica image installed:
###    docker build . --build-arg LIBERICA_IMAGE_VARIANT=[standard|lite|base|base-minimal]
### base: minimal image with compressed java.base module, Server VM and optional files stripped, ~37 MB with Alpine base
### base-minimal: minimal image with compressed java.base module, Minimal VM and optional files stripped
### lite: lite image with minimal footprint and Server VM, ~ 100 MB
### standard: standard jdk image with Server VM and jmods, can be used to create arbirary module set, ~180 MB

ENV  LANG=en_US.UTF-8 \
     LANGUAGE=en_US:en
#	 LC_ALL=en_US.UTF-8

ARG LIBERICA_IMAGE_VARIANT=custom
ARG LIBERICA_VM="server"

ARG LIBERICA_JVM_DIR=/usr/lib/jvm
ARG LIBERICA_VERSION=17.0.1
ARG LIBERICA_BUILD=12

ARG LIBERICA_ROOT=${LIBERICA_JVM_DIR}/jdk-${LIBERICA_VERSION}-bellsoft
ARG GLIBC=yes

RUN \
    set +x && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh            \
    &&    LIBSUFFIX=""                                               \
    &&    if [ "$GLIBC" = "no" ]; then LIBSUFFIX="-musl";            \
          else                                                       \
            wget -nv -O /etc/apk/keys/sgerrand.rsa.pub               \
                https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub    \
    &&      for pkg in glibc glibc-bin ; do                          \
                wget -nv -O ${pkg}-${GLIBC_VERSION}.apk              \
                    https://github.com/${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}-${GLIBC_VERSION}.apk    \
    &&          apk add --no-cache ${pkg}-${GLIBC_VERSION}.apk       \
    &&          rm ${pkg}-${GLIBC_VERSION}.apk ;                     \
            done                                                     \
          fi                                                         \
  && LIBERICA_ARCH=''                    \
  &&    case `uname -m` in               \
            x86_64)                      \
                LIBERICA_ARCH="amd64"    \
                ;;                       \
            aarch64)                     \
                LIBERICA_ARCH="aarch64"  \
                ;;                       \
            *)                           \
                LIBERICA_ARCH=`uname -m` \
                ;;                       \
        esac                             \
  &&    case "$LIBERICA_IMAGE_VARIANT" in                                   \
            standard|custom)                                                \
                RSUFFIX="-full"                                             \
  &&            LITE_URL="" ;;                                              \
            lite|base|base-minimal)                                         \
                RSUFFIX="-lite"                                             \
  &&            LITE_URL="/docker" ;;                                       \
            *) echo "Invalid parameter LIBERICA_IMAGE_VARIANT = ${LIBERICA_IMAGE_VARIANT}"    \
  &&           echo "LIBERICA_IMAGE_VARIANT can be one of [standard|lite|base|base-minimal]"  \
  &&           exit 1 ;; \
         esac            \
  &&  if [[ ${LIBERICA_IMAGE_VARIANT} == "standard" || ${LIBERICA_IMAGE_VARIANT} == "lite" ]]; then \
        case $LIBERICA_VM in                                                                        \
          server|client|minimal|all) echo ;;                                                        \
          *) echo "Only server, client, minimal or all VM is avalable for LIBERICA_VM argument"     \
  &&            echo "example: LIBERICA_VM='server'"                                                \
  &&            exit 1                                                                              \
           ;; \
        esac; \
      fi      \
  &&    for pkg in $OPT_PKGS ; do apk --no-cache add $pkg ; done            \
  &&    mkdir -p /tmp/java                                                  \
  &&    LIBERICA_BUILD_STR=${LIBERICA_BUILD:+"+${LIBERICA_BUILD}"}          \
  &&    PKG="bellsoft-jdk${LIBERICA_VERSION}${LIBERICA_BUILD_STR}-linux-${LIBERICA_ARCH}${LIBSUFFIX}${RSUFFIX}.tar.gz" \
  &&    PKG_URL="https://download.bell-sw.com/java/${LIBERICA_VERSION}${LIBERICA_BUILD_STR}${LITE_URL}/${PKG}"         \
  &&    echo "Download ${PKG_URL}"                                                                   \
  &&    wget "${PKG_URL}" -O /tmp/java/jdk.tar.gz                                                    \
  &&    SHA_URL="https://download.bell-sw.com/java/${LIBERICA_VERSION}${LIBERICA_BUILD_STR}/docker/sha1sum.txt" \
  &&    if [[ ${LIBERICA_IMAGE_VARIANT} == "standard" || ${LIBERICA_IMAGE_VARIANT} == "custom" ]]; then         \
          SHA_URL="https://download.bell-sw.com/sha1sum/java/${LIBERICA_VERSION}${LIBERICA_BUILD_STR}";         \
        fi \
  &&    SHA1=$(wget -q "${SHA_URL}" -O -          \
               | grep ${PKG}                      \
               | cut -f1 -d' '                    \
              )                                   \
  &&    echo "${SHA1} */tmp/java/jdk.tar.gz" | sha1sum -c - \
  &&    tar xzf /tmp/java/jdk.tar.gz -C /tmp/java           \
  &&    UNPACKED_ROOT=/tmp/java/jdk-${LIBERICA_VERSION}*    \
  &&    case $LIBERICA_IMAGE_VARIANT in                     \
            custom)                                         \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --no-header-files                       \
                    --add-modules                           \
                       $(echo $OPT_JMODS | sed -e "s/ /,/g")\
                    --no-man-pages --strip-debug            \
                    --vm=server                             \
                    --output "${LIBERICA_ROOT}"             \
  &&            mkdir -p ${LIBERICA_ROOT}/jmods/            \
  &&            for JMOD in $OPT_JMODS ;                    \
                    do cp "/tmp/java/jdk-${LIBERICA_VERSION}${RSUFFIX}/jmods/${JMOD}.jmod" "${LIBERICA_ROOT}/jmods/${JMOD}.jmod" ; \
                done                                        \
  &&            apk del binutils ;;                         \
            base)                                           \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --add-modules java.base                 \
                    --compress=2                            \
                    --no-header-files                       \
                    --no-man-pages --strip-debug            \
                    --module-path ${UNPACKED_ROOT}/jmods    \
                    --vm=server                             \
                    --output "${LIBERICA_ROOT}"             \
  &&            apk del binutils ;;                         \
            base-minimal)                                   \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --add-modules java.base                 \
                    --compress=2                            \
                    --no-header-files                       \
                    --no-man-pages --strip-debug            \
                    --module-path ${UNPACKED_ROOT}/jmods    \
                    --vm=minimal                            \
                    --output "${LIBERICA_ROOT}"             \
  &&            apk del binutils ;;                         \
            standard)                                       \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_ROOT}"                \
  &&            find /tmp/java/jdk*                         \
                    -maxdepth 1 -mindepth 1                 \
                    -exec                                   \
                      mv -v "{}" "${LIBERICA_ROOT}/" \;     \
  &&            case ${LIBERICA_VM} in                    \
                  client)                                 \
                    rm -rf ${LIBERICA_ROOT}/lib/server    \
  &&                rm -rf ${LIBERICA_ROOT}/lib/minimal   \
  &&                echo "-client KNOWN"                  \
                      >  ${LIBERICA_ROOT}/lib/jvm.cfg     \
  &&                echo "-server ALIASED_TO -client"     \
                      >> ${LIBERICA_ROOT}/lib/jvm.cfg     \
                  ;;                                      \
                  server)                                 \
                    rm -rf ${LIBERICA_ROOT}/lib/client    \
  &&                rm -rf ${LIBERICA_ROOT}/lib/minimal   \
  &&                echo "-server KNOWN"                  \
                      >  ${LIBERICA_ROOT}/lib/jvm.cfg     \
  &&                echo "-client ALIASED_TO -server"     \
                      >> ${LIBERICA_ROOT}/lib/jvm.cfg     \
                  ;;                                      \
                  minimal)                                \
                   ([ ! -f ${LIBERICA_ROOT}/lib/minimal ] \
  &&                  echo "Standard Liberica JDK does not have minimal VM" \
  &&                  exit 1 )                            \
  &&                rm -rf ${LIBERICA_ROOT}/lib/server    \
  &&                rm -rf ${LIBERICA_ROOT}/lib/minimal   \
  &&                echo "-minimal KNOWN"                 \
                      >  ${LIBERICA_ROOT}/lib/jvm.cfg     \
  &&                echo "-client ALIASED_TO -minimal"    \
                      >> ${LIBERICA_ROOT}/lib/jvm.cfg     \
  &&                echo "-client ALIASED_TO -minimal"    \
                      >> ${LIBERICA_ROOT}/lib/jvm.cfg     \
                  ;;                                      \
                  all) echo ;;                            \
                  *) echo "Unknows LIBERICA_VM value \"${LIBERICA_VM}\"" \
  &&                 exit 1 ;;                            \
                esac                                      \
  &&            apk del binutils                          \
            ;;                                            \
            *)                                            \
                MODS=$(ls ${UNPACKED_ROOT}/jmods/        \
                      | sed "s/.jmod//"                   \
                      | grep -v javafx                    \
                      | tr '\n' ', '                      \
                      | sed "s/,$//")                     \
  &&            apk --no-cache add binutils               \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"           \
  &&            ${UNPACKED_ROOT}/bin/jlink                \
                    --add-modules ${MODS}                 \
                    --compress=2                          \
                    --no-man-pages                        \
                    --module-path ${UNPACKED_ROOT}/jmods  \
                    --vm=${LIBERICA_VM}                   \
                    --output "${LIBERICA_ROOT}"           \
  &&            apk del binutils ;;                       \
        esac                                              \
  &&    ln -s $LIBERICA_ROOT /usr/lib/jvm/jdk             \
  &&    rm -rf /tmp/java                                  \
  &&    rm -rf /tmp/hsperfdata_root

ENV JAVA_HOME=${LIBERICA_ROOT} \
	PATH=${LIBERICA_ROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /app/launchserver

COPY --from=launcher-base /root/ls /defaults
COPY root/ /

VOLUME ["/app/launchserver"]

EXPOSE 9274
CMD ["s6-setuidgid", "abc", "java", "-Dlaunchserver.dockered=true", "-javaagent:LaunchServer.jar", "-jar", "LaunchServer.jar"]
