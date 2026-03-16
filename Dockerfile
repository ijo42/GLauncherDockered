FROM --platform=$BUILDPLATFORM debian:12-slim as glibc-base

ARG GLIBC_VERSION=2.40
ARG GLIBC_PREFIX=/usr/glibc
ARG LANG=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

RUN     apt-get update \
  &&    apt-get install -y curl build-essential gawk bison python3 texinfo gettext \
  &&    cd /root \
  &&    curl -SL https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz | tar xzf - \
  &&    mkdir -p /root/build \
  &&    cd /root/build \
  &&    ../glibc-${GLIBC_VERSION}/configure \
          --prefix=${GLIBC_PREFIX} \
          --libdir="${GLIBC_PREFIX}/lib" \
          --libexecdir="${GLIBC_PREFIX}/lib" \
          --enable-multi-arch \
          --enable-stack-protector=strong \
  &&    make -j`nproc` \
  &&    make DESTDIR=/root/dest install \
  &&    RTLD=`find /root/dest${GLIBC_PREFIX}/lib -name 'ld-linux-*.so.*'` \
  &&    [ -x "$RTLD" ] \
  &&    LOCALEDEF="$RTLD --library-path /root/dest${GLIBC_PREFIX}/lib /root/dest${GLIBC_PREFIX}/bin/localedef --alias-file=/root/glibc-${GLIBC_VERSION}/intl/locale.alias" \
  &&    export I18NPATH=/root/glibc-${GLIBC_VERSION}/localedata \
  &&    export GCONVPATH=/root/glibc-${GLIBC_VERSION}/iconvdata \
  &&    LOCALE=$(echo ${LANG} | cut -d. -f1) \
  &&    CHARMAP=$(echo ${LANG} | cut -d. -f2) \
  &&    mkdir -pv /root/dest${GLIBC_PREFIX}/lib/locale \
  &&    cd /root/glibc-${GLIBC_VERSION}/localedata \
  &&    ${LOCALEDEF} -i locales/$LOCALE -f charmaps/$CHARMAP --prefix=/root/dest $LANG \
  &&    cd /root \
  &&    rm -rf build glibc-${GLIBC_VERSION} \
  &&    cd /root/dest${GLIBC_PREFIX} \
  &&    ( strip bin/* sbin/* lib/* || true ) \
  &&    echo "/usr/local/lib" > /root/dest${GLIBC_PREFIX}/etc/ld.so.conf \
  &&    echo "${GLIBC_PREFIX}/lib" >> /root/dest${GLIBC_PREFIX}/etc/ld.so.conf \
  &&    echo "/usr/lib" >> /root/dest${GLIBC_PREFIX}/etc/ld.so.conf \
  &&    echo "/lib" >> /root/dest${GLIBC_PREFIX}/etc/ld.so.conf

RUN cd /root/dest${GLIBC_PREFIX} && \
  rm -rf etc/rpc var include share bin sbin/[^l]*  \
	lib/*.o lib/*.a lib/audit lib/gconv lib/getconf


# DOWNLOAD OR BUILD LAUNCHSERVER FILES
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk-alpine as launcher-base

### Modify argument LAUNCHER_VERSION or redefine it via --build-arg parameter to have specific LaunchServer version installed:
###    docker build . --build-arg LAUNCHER_VERSION=v5.1.8
### Modify argument RUNTIME_VERSION  or redefine it via --build-arg parameter to have specific Runtime version installed:
###    docker build . --build-arg RUNTIME_VERSION=v1.4.0

ARG LAUNCHER_VERSION=master
ARG RUNTIME_VERSION=master
ARG GITHUB_REPO="GravitLauncher/Launcher"
ARG GITHUB_RUNTIME_REPO="GravitLauncher/LauncherRuntime"
ENV DEBIAN_FRONTEND=noninteractive

RUN apk add --no-cache git && \
    mkdir -p /root/ls/launcher-modules /root/ls/runtime && set -e && \
    echo "Clone main repository" && \
    git clone -b dev https://github.com/${GITHUB_REPO}.git src && \
    cd src && \
    sed -i 's/git@github.com:/https:\/\/github.com\//' .gitmodules && \
    git checkout $LAUNCHER_VERSION && \
    git submodule sync && \
    git submodule update --init --recursive && \
    echo "Build" && \
    ./gradlew build installDist -Dorg.gradle.daemon=false || ( echo "Build failed. Stopping" && exit 101 ) && \
    ./gradlew :components:launcher-api:publishToMavenLocal \
              :components:launcher-client:publishToMavenLocal \
              :components:launcher-core:publishToMavenLocal \
              :components:launcher-runtime:publishToMavenLocal \
              :components:launcher-start:publishToMavenLocal \
              -Dorg.gradle.daemon=false && \
    PTH=components/launchserver/build/install/launchserver && \
	for dir in "bin" "lib"; do \
		if [ -e "${PTH}/${dir}" ]; then \
			cp -R "${PTH}/${dir}" /root/ls; \
		else \
			echo "[E] ${PTH}/${dir} does not exists"; \
		fi \
	done && \
    cd .. \
  && \
    echo "Clone runtime repository" && \
    git clone -b dev https://github.com/${GITHUB_RUNTIME_REPO}.git srcRuntime && \
    cd srcRuntime && \
    git checkout $RUNTIME_VERSION && \
    ./gradlew build -Dorg.gradle.daemon=false || ( echo "Build failed. Stopping" && exit 102 ) && \
    cp $(echo build/libs/JavaRuntime*.jar) /root/ls/launcher-modules/ && \
    cp -R runtime/* /root/ls/runtime/


# DOWNLOAD LIBERICA JDK (use Debian for reliable SSL)
FROM --platform=$BUILDPLATFORM debian:12-slim as liberica-download

ARG LIBERICA_VERSION=21.0.1
ARG LIBERICA_BUILD=12
ARG LIBERICA_IMAGE_VARIANT=custom
ARG GITHUB_RELEASES_URL="https://github.com/bell-sw/Liberica/releases/download"

RUN apt-get update -q \
  && apt-get install -y --no-install-recommends wget ca-certificates \
  && LIBERICA_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/i686/i586/;s/armv[67]l/arm32-vfp-hflt/;s/ppc64le/ppc64le/') \
  && case "$LIBERICA_IMAGE_VARIANT" in \
       standard|custom) RSUFFIX="-full" ;; \
       *) RSUFFIX="-lite" ;; \
     esac \
  && LIBERICA_BUILD_STR=${LIBERICA_BUILD:+"+${LIBERICA_BUILD}"} \
  && LIBERICA_BUILD_STR_ENC=$(echo "$LIBERICA_BUILD_STR" | sed 's/+/%2B/g') \
  && PKG="bellsoft-jdk${LIBERICA_VERSION}${LIBERICA_BUILD_STR}-linux-${LIBERICA_ARCH}${RSUFFIX}.tar.gz" \
  && PKG_ENC="bellsoft-jdk${LIBERICA_VERSION}${LIBERICA_BUILD_STR_ENC}-linux-${LIBERICA_ARCH}${RSUFFIX}.tar.gz" \
  && TAG_ENC="${LIBERICA_VERSION}${LIBERICA_BUILD_STR_ENC}" \
  && mkdir -p /tmp/java \
  && wget -q "${GITHUB_RELEASES_URL}/${TAG_ENC}/${PKG_ENC}" -O /tmp/java/jdk.tar.gz


# BUILD FINAL IMAGE
# src: https://github.com/bell-sw/Liberica/blob/8548f0d9f76f6e70389daa19f6d705ed08cfeed9/docker/repos/liberica-openjdk-alpine/17/Dockerfile

FROM --platform=$BUILDPLATFORM lsiobase/alpine:3.20-version-20d93760 as liberica

LABEL maintainer="ijo42 <admin@ijo42.ru>"

ARG GLIBC_PREFIX=/usr/glibc
ARG EXT_GCC_LIBS_URL=https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-8.3.0-1-x86_64.pkg.tar.xz
ARG EXT_ZLIB_URL=https://archive.archlinux.org/packages/z/zlib/zlib-1%3A1.2.11-3-x86_64.pkg.tar.xz
ARG LANG=en_US.UTF-8

ARG OPT_PKGS="bash unzip"
ARG OPT_JMODS="java.base,java.net.http,java.instrument,jdk.management,java.scripting,java.sql,jdk.unsupported,java.naming,java.desktop,jdk.crypto.cryptoki,jdk.crypto.ec,javafx.base,javafx.graphics,javafx.controls"

ENV  LANG=${LANG} \
     LANGUAGE=${LANG}:en
#	 LC_ALL=en_US.UTF-8

ARG LIBERICA_IMAGE_VARIANT=custom
ARG LIBERICA_VM="server"
ARG LIBERICA_GENERATE_CDS=false

ARG LIBERICA_JVM_DIR=/usr/lib/jvm
ARG LIBERICA_VERSION=21.0.1
ARG LIBERICA_BUILD=12

ARG LIBERICA_ROOT=${LIBERICA_JVM_DIR}/jdk-${LIBERICA_VERSION}-bellsoft

COPY --from=glibc-base /root/dest/ /
COPY --from=liberica-download /tmp/java/jdk.tar.gz /tmp/java/jdk.tar.gz

SHELL ["/bin/bash", "-c"]
RUN LIBERICA_ARCH=''                               \
  && apk --no-cache upgrade libcrypto1.1 libssl1.1 \
  && set -x                                        \
  &&    case `uname -m` in                         \
            x86_64)                                \
                LIBERICA_ARCH="amd64"              \
                ;;                                 \
            i686)                                  \
                LIBERICA_ARCH="i586"               \
                ;;                                 \
            aarch64)                               \
                LIBERICA_ARCH="aarch64"            \
                ;;                                 \
            armv[67]l)                             \
                LIBERICA_ARCH="arm32-vfp-hflt";    \
                ;;                                 \
            ppc64le)                               \
                LIBERICA_ARCH="ppc64le";           \
                ;;                                 \
            *)                                     \
                LIBERICA_ARCH=`uname -m`           \
                ;;                                 \
        esac                                       \
  &&    ln -s ${GLIBC_PREFIX}/lib/ld-*.so* /lib                   \
  &&    ln -s ${GLIBC_PREFIX}/etc/ld.so.cache /etc/ld.so.cache   \
  &&    ln -s ${GLIBC_PREFIX}/etc/ld.so.conf /etc/ld.so.conf    \
  &&    if [ "$LIBERICA_ARCH" = "amd64" ]; then                   \
          ln -s /lib /lib64                                       \
  &&      mkdir /tmp/zlib                                         \
  &&      wget -O - "${EXT_ZLIB_URL}" | tar xJf - -C /tmp/zlib    \
  &&      cp -dP /tmp/zlib/usr/lib/libz.so* "${GLIBC_PREFIX}/lib" \
  &&      rm -rf /tmp/zlib                                        \
  &&      mkdir /tmp/gcc                                          \
  &&      wget -O - "${EXT_GCC_LIBS_URL}" | tar xJf - -C /tmp/gcc \
  &&      cp -dP /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* "${GLIBC_PREFIX}/lib" \
  &&      rm -rf /tmp/gcc;     \
        fi                     \
  &&    for pkg in $OPT_PKGS ; do apk --no-cache add $pkg ; done \
  &&    ldconfig || true                                          \
  &&    echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf \
  &&    mkdir -p /tmp/java                                                  \
  &&    tar xzf /tmp/java/jdk.tar.gz -C /tmp/java           \
  &&    UNPACKED_ROOT=/tmp/java/jdk-${LIBERICA_VERSION}*    \
  &&    case $LIBERICA_IMAGE_VARIANT in                     \
            custom)                                         \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --no-header-files                       \
                    --add-modules $OPT_JMODS                \
                    --module-path $UNPACKED_ROOT/jmods      \
                    --no-man-pages --strip-debug            \
                    --release-info ${UNPACKED_ROOT}/release \
                    --vm=server                             \
                    --output "${LIBERICA_ROOT}"             \
  &&            mkdir -p ${LIBERICA_ROOT}/jmods/            \
  &&            for JMOD in  \
                    $(echo $OPT_JMODS | sed -e "s/,/ /g") ; \
                    do cp $UNPACKED_ROOT/jmods/${JMOD}.jmod  \
                       "${LIBERICA_ROOT}/jmods/${JMOD}.jmod" ; \
                done                                        \
  &&            apk del binutils ;;                         \
            base)                                           \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --add-modules java.base                 \
                    --compress=zip-9                            \
                    --no-header-files                       \
                    --no-man-pages --strip-debug            \
                    --module-path ${UNPACKED_ROOT}/jmods    \
                    --vm=server                             \
                    --release-info ${UNPACKED_ROOT}/release \
                    --output "${LIBERICA_ROOT}"             \
  &&            apk del binutils ;;                         \
            base-minimal)                                   \
                apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --add-modules java.base                 \
                    --compress=zip-9                            \
                    --no-header-files                       \
                    --no-man-pages --strip-debug            \
                    --module-path ${UNPACKED_ROOT}/jmods    \
                    --vm=minimal                            \
                    --release-info ${UNPACKED_ROOT}/release \
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
                    ([ ! -f ${LIBERICA_ROOT}/lib/minimal ]\
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
  &&            apk del binutils ;;                       \
            *)                                              \
                MODS=$( ls ${UNPACKED_ROOT}/jmods/          \
                      | sed "s/.jmod//"                     \
                      | grep -v javafx                      \
                      | tr '\n' ', '                        \
                      | sed "s/,$//")                       \
  &&            apk --no-cache add binutils                 \
  &&            mkdir -pv "${LIBERICA_JVM_DIR}"             \
  &&            ${UNPACKED_ROOT}/bin/jlink                  \
                    --add-modules ${MODS}                   \
                    --compress=zip-9                        \
                    --no-man-pages                          \
                    --module-path ${UNPACKED_ROOT}/jmods    \
                    --vm=${LIBERICA_VM}                     \
                    --release-info ${UNPACKED_ROOT}/release \
                    --output "${LIBERICA_ROOT}"             \
  &&            apk del binutils ;;                         \
        esac                                                \
  &&    ln -s $LIBERICA_ROOT /usr/lib/jvm/jdk               \
  &&    if [[ $LIBERICA_GENERATE_CDS == true ]]; then                    \
        ${LIBERICA_ROOT}/bin/java -XX:+UseCompressedOops -Xshare:dump;   \
        ${LIBERICA_ROOT}/bin/java -XX:-UseCompressedOops -Xshare:dump;   \
    else                                                                 \
        find ${LIBERICA_ROOT} -name "classes*.jsa" -exec rm {} \; ;      \
    fi                               \
  &&    rm -rf /tmp/java             \
  &&    rm -rf /tmp/hsperfdata_root

ENV JAVA_HOME=${LIBERICA_ROOT} \
	PATH=${LIBERICA_ROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
	JAVA_OPTS="-Dlaunchserver.dockered=true"

WORKDIR /app/launchserver

COPY --from=launcher-base /root/ls /defaults
COPY root/ /

VOLUME ["/app/launchserver"]

EXPOSE 9274
CMD ["s6-setuidgid", "abc", "/app/launchserver/bin/launchserver"]
