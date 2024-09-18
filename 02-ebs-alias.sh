#!/bin/bash

# Please review the README file before making updates

echo "===> UserData $(basename $BASH_SOURCE) Script: Start"

echo "Create a temporary symbolic link to retrieve UUID on first boot"

VOLUMES_NAME=$(nvme list | grep -i "Amazon Elastic Block Store" | awk '{ print $1 }')

echo "---> Volumes list:"
echo ${VOLUMES_NAME[@]} | tr " " "\n"

for VOLUME in ${VOLUMES_NAME}
do
    ALIAS=$(nvme id-ctrl -v "${VOLUME}" | grep -Po '"(/dev/)?(sd[b-z]|xvd[b-z])' | sed -E 's/"(\/dev\/)?/\/dev\//')
    if [[ ! -z "${ALIAS}" ]]
    then
        echo "---> Create link from ${VOLUME} to ${ALIAS}"
        ln -s "${VOLUME}" "${ALIAS}"
    fi
done

