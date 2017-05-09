#!/bin/bash

# ask for confirm
while true; do
    read -p "Do you really want to drop containers? (y/n): " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# stop containers
docker ps -a -f NAME=rpl_mysql --format "{{.Names}}" | xargs -I{} docker stop {}

# drop containers
docker ps -a -f NAME=rpl_mysql --format "{{.Names}}" | xargs -I{} docker rm {}

# drop shared data
sudo rm -rf ./shared
