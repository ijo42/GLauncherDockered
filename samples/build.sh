#!/bin/bash
read -e -p "Enter LaunchServer User Name:" -i "launchserver" NAME

docker image build --build-arg user_id=$(id -u $NAME) --build-arg group_id=$(id -g $NAME) --tag local/launchserver $(pwd)