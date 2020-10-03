#!/bin/bash
read -e -p "Enter LaunchServer User Name:" -i "launchserver" NAME

docker image build --build-arg UID=$(id -u $NAME) --build-arg GID=$(id -g $NAME) --tag local/launchserver $(pwd)
