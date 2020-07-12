#!/bin/bash -e
TMP="/tmp/ls"
if [ ! -d "/launchserver/launcher-libraries" ]; then cp -r ${TMP}/launcher-libraries /launchserver; fi
if [ ! -d "/launchserver/launcher-libraries-compile" ]; then cp -r ${TMP}/launcher-libraries-compile /launchserver; fi
if [ ! -d "/launchserver/libraries" ]; then cp -r ${TMP}/libraries /launchserver; fi
if [ ! -f "/launchserver/LaunchServer.jar" ]; then cp ${TMP}/LaunchServer.jar /launchserver; fi

if [ ! -d "/launchserver/launcher-modules" ]; then cp -r ${TMP}/launcher-modules /launchserver; fi
if [ ! -d "/launchserver/runtime" ]; then cp -r ${TMP}/runtime /launchserver; fi


java -Dlaunchserver.dockered=true -Dlauncher.dev=true -javaagent:/launchserver/LaunchServer.jar=/launchserver/libraries -jar /launchserver/LaunchServer.jar
