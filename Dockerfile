# DOWNLOAD OR BUILD LAUNCHSERVER FILES

FROM bellsoft/liberica-openjdk-debian:11 as launcher-base

### Modify argument LAUNCHER_VERSION or redefine it via --build-arg parameter to have specific LaunchServer version installed:
###    docker build . --build-arg LAUNCHER_VERSION=5.1.8
### Modify argument RUNTIME_VERSION  or redefine it via --build-arg parameter to have specific Runtime version installed:
###    docker build . --build-arg RUNTIME_VERSION=1.4.0

ARG LAUNCHER_VERSION=latest
ARG RUNTIME_VERSION=latest
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update < /dev/null && apt-get install -qq curl wget unzip git < /dev/null && mkdir -p /root/ls /tmp/ls
##&& \ TODO: BACK IT
RUN  \
  if [ $LAUNCHER_VERSION = v* ] || [ $LAUNCHER_VERSION = "latest" ] ; then TAG_LS="latest" && \
    if [ ! $LAUNCHER_VERSION = "latest" ]; then TAG_LS="tags/${LAUNCHER_VERSION}"; fi && \
    wget -nv -O /tmp/ls/artficats.zip \
      $(curl -s https://api.github.com/repos/GravitLauncher/Launcher/releases/$TAG_LS | grep browser_download_url | cut -d '"' -f 4) && \
    unzip -q /tmp/ls/artficats.zip -d /root/ls && unzip -q /root/ls/libraries.zip -d /root/ls && \
    rm -f /root/ls/libraries.zip; \
  else \
    echo -e "\033[32mPhase 1: \033[33mClone main repository\033[m" && \
    git clone -b dev https://github.com/GravitLauncher/Launcher.git src && \
    cd src && \
    sed -i 's/git@github.com:/https:\/\/github.com\//' .gitmodules && \
    git checkout $LAUNCHER_VERSION && \
    git submodule sync && \
    git submodule update --init --recursive && \
    echo -e "\033[32mPhase 2: \033[33mBuild\033[m" && \
    ./gradlew -Dorg.gradle.daemon=false build || ( echo -e "\033[31mBuild failed. Stopping\033[m" && exit 101 ) && \
    cp -R LaunchServer.jar launcher-libraries launcher-libraries-compile libraries /root/ls && \
    cd ..; \
  fi && \
  if [ $RUNTIME_VERSION = v* ] || [ $RUNTIME_VERSION = "latest" ] ; then TAG_RT="latest" && \
    if [ ! $RUNTIME_VERSION = "latest" ]; then TAG_RT="tags/${RUNTIME_VERSION}"; fi && \
    wget -nv -O /tmp/ls/runtime_artficats.zip \
      $(curl -s https://api.github.com/repos/GravitLauncher/LauncherRuntime/releases/$TAG_RT | grep browser_download_url | cut -d '"' -f 4) && \
    unzip -q /tmp/ls/runtime_artficats.zip -d /root/ls/launcher-modules && unzip -q /root/ls/launcher-modules/runtime.zip -d /root/ls/runtime && \
    rm -f /root/ls/launcher-modules/runtime.zip \
  else \
    echo -e "\033[32mPhase 3: \033[33mClone runtime repository\033[m" && \
    git clone -b dev https://github.com/GravitLauncher/LauncherRuntime.git srcRuntime && \
    cd srcRuntime && \
    git checkout $RUNTIME_VERSION && \
    ./gradlew -Dorg.gradle.daemon=false build || ( echo -e "\033[31mBuild failed. Stopping\033[m" && exit 102 ) && \
    cp build/libs/JavaRuntime-* /root/ls/launcher-modules/ && \
    cp -R runtime/* /root/ls/runtime/ && \
    cd ..; \
  fi

# DOWNLOAD LIBERICA JDK

FROM alpine:latest as liberica

### Modify argument LIBERICA_IMAGE_VARIANT or redefine it via --build-arg parameter to have specific liberica image installed:
###    docker build . --build-arg LIBERICA_IMAGE_VARIANT=[full|lite|base]
### base: minimal image with compressed java.base module, Server VM and optional files stripped, ~37 MB with Alpine base
### full: full jdk image with Server VM and jmods, can be used to create arbirary module set, ~180 MB

ENV  LANG=en_US.UTF-8 \
		 LANGUAGE=en_US:en
#	 LC_ALL=en_US.UTF-8

ARG LIBERICA_IMAGE_VARIANT=base

ARG LIBERICA_JVM_DIR=/usr/lib/jvm
ARG LIBERICA_ROOT=${LIBERICA_JVM_DIR}/jdk-bellsoft
ARG LIBERICA_VERSION=11.0.8
ARG LIBERICA_BUILD=10
ARG LIBERICA_VARIANT=jdk
ARG LIBERICA_RELEASE_TAG=
ARG LIBERICA_ARCH=x64
ARG LIBERICA_GLIBC=no

ARG OPT_PKGS="bash unzip"
ARG GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc
ARG GLIBC_VERSION=2.32-r0
ARG OPT_JMODS="java.base java.instrument jdk.management java.scripting java.sql jdk.unsupported java.naming java.desktop"
ARG OPT_JFXMODS="javafx.base javafx.graphics javafx.controls"

COPY --from=launcher-base /root /tmp

RUN apk --no-cache -U upgrade && \
	echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
	wget -nv -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub && \
	wget -nv -O /tmp/glibc-${GLIBC_VERSION}.apk ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
	wget -nv -O /tmp/glibc-bin-${GLIBC_VERSION}.apk ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
	apk --no-cache add /tmp/*.apk && rm -v /tmp/*.apk && \
	RTAG="$LIBERICA_RELEASE_TAG" && if [ "x${RTAG}" = "x" ]; then RTAG="$LIBERICA_VERSION"; fi && \
	LIBSUFFIX="" && if [ "$LIBERICA_GLIBC" = "no" ]; then LIBSUFFIX="-musl"; fi && \
	for pkg in $OPT_PKGS ; do apk --no-cache add $pkg ; done && mkdir -p /tmp/java && \
	LIBERICA_BUILD_STR=${LIBERICA_BUILD:+"+${LIBERICA_BUILD}"} && \
	PKG=`echo "bellsoft-${LIBERICA_VARIANT}${LIBERICA_VERSION}${LIBERICA_BUILD_STR}-linux-${LIBERICA_ARCH}${LIBSUFFIX}.tar.gz"` && \
	wget -nv -O /tmp/java/jdk.tar.gz "https://download.bell-sw.com/java/${LIBERICA_VERSION}${LIBERICA_BUILD_STR}/${PKG}" && \
	SHA1=`wget -q "https://download.bell-sw.com/sha1sum/java/${LIBERICA_VERSION}${LIBERICA_BUILD_STR}" -O - | grep ${PKG} | cut -f1 -d' '` && \
	echo "${SHA1} */tmp/java/jdk.tar.gz" | sha1sum -c - && tar xzf /tmp/java/jdk.tar.gz -C /tmp/java && \
	UNPACKED_ROOT="/tmp/java/${LIBERICA_VARIANT}-${LIBERICA_VERSION}${RUSUFFIX}" && \
	if [ "$LIBERICA_IMAGE_VARIANT" = "base" ]; then mkdir -p "${LIBERICA_JVM_DIR}" && MODS=`echo ${OPT_JMODS} | sed "s/ /,/g" | sed "s/,$//"` && "${UNPACKED_ROOT}/bin/jlink" --add-modules "${MODS}" \
	  --no-header-files --no-man-pages --strip-debug --module-path "${UNPACKED_ROOT}"/jmods --vm=server --output "${LIBERICA_ROOT}"; fi && \
	if [ "$LIBERICA_IMAGE_VARIANT" = "full" ]; then mkdir -p "${LIBERICA_JVM_DIR}" && MODS=`ls "${UNPACKED_ROOT}/jmods/" | sed "s/.jmod//" | grep -v javafx | tr '\n' ', ' | sed "s/,$//"` && \
		"${UNPACKED_ROOT}/bin/jlink" --add-modules "${MODS}" --module-path "${UNPACKED_ROOT}/jmods" --vm=server --output "${LIBERICA_ROOT}"; fi && \
	mkdir -p "${LIBERICA_ROOT}/jmods" && ln -s "${LIBERICA_ROOT}" /usr/lib/jvm/jdk && \
	wget -nv -O /entrypoint "https://github.com/ijo42/GravitLauncherDockered/raw/master/entrypoint" && chmod +x /entrypoint && \
	wget -nv -O /tmp/javafx-jmods.zip "https://gluonhq.com/download/javafx-11-0-2-jmods-linux/" && unzip -q /tmp/javafx-jmods.zip -d /tmp/ && \
	for JMOD in $OPT_JFXMODS ; do cp "/tmp/javafx-jmods-11.0.2/${JMOD}.jmod" "${LIBERICA_ROOT}/jmods/${JMOD}.jmod" ; done && \
	for JMOD in $OPT_JMODS   ; do cp   "${UNPACKED_ROOT}/jmods/${JMOD}.jmod" "${LIBERICA_ROOT}/jmods/${JMOD}.jmod" ; done && \
	rm -rf /tmp/java /tmp/javafx-* /tmp/hsperfdata_root

ENV JAVA_HOME=${LIBERICA_ROOT} \
	PATH=${LIBERICA_ROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 9274
ENTRYPOINT [ "/entrypoint" ]
