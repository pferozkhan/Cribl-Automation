#!/bin/bash

# Please review the README file before making updates

set -o nounset
#set -o errexit
set -o pipefail


# == Vars
#
VOLUME_NAME="/dev/sdf"
MOUNT_POINT="/swap"
FS="swap"


# == Main
#
echo "===> UserData $(basename $BASH_SOURCE) Script: Start"

echo "# Waiting for ${VOLUME_NAME} (. = 5s, max 4mins)"
COUNTER=0
while [[ ! -e ${VOLUME_NAME} ]]; do
  if [ ${COUNTER} -eq 48 ]; then
    echo "Timeout exceeded (4mins) - ${VOLUME_NAME} is not found"
    exit 1
  fi

  sleep 5s;
  echo -n "."
  let COUNTER=${COUNTER}+1
done


if [[ "${FS}" == "swap" ]]
then
  echo "# Disable existing swap, create new and extend swap space"
  swapoff -v ${VOLUME_NAME}
  mkswap ${VOLUME_NAME}
else
  echo "# Create File System, format the disk only if it is unformatted"
  blkid $(readlink -f ${VOLUME_NAME}) || mkfs -t ${FS} ${VOLUME_NAME}

  echo "# Create mount point directory ${MOUNT_POINT}"
  mkdir -p ${MOUNT_POINT}
fi

echo "# Retrieve UUID of ${VOLUME_NAME}"
VOLUME_UUID=$(blkid -s UUID -o value ${VOLUME_NAME})

if [[ -z "$(grep -i "${VOLUME_UUID}" /etc/fstab)" ]]
then
  if [[ "${FS}" == "swap" ]]
  then
    echo "# Activate swap and save to /etc/fstab"
    swapon -v ${VOLUME_NAME}
    echo "UUID="${VOLUME_UUID}" none swap defaults 0 0" | sudo tee -a /etc/fstab

    echo "# Swap verification"
    cat /proc/swaps
    free -h
    swapon --show
  else
    echo "# Mount and save to /etc/fstab"
    mount UUID="${VOLUME_UUID}" ${MOUNT_POINT}
    echo "UUID="${VOLUME_UUID}" ${MOUNT_POINT} ${FS} defaults,nofail 0 2" | sudo tee -a /etc/fstab
  fi
  
  echo "# Reload systemd manager configuration"
  systemctl daemon-reload
fi

if [[ "${FS}" == "ext4" ]]
then
  echo "# If ext4, extend file system if needed"
  resize2fs ${VOLUME_NAME}
fi

echo "===> UserData Script: Done"

