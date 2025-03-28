#!/bin/bash

# Please review the README file before making updates

echo "===> UserData $(basename $BASH_SOURCE) Script: Start"

set -ex

EFS_DNS_NAME="<>.<>.<>-west-1.amazonaws.com"
MOUNT_POINT="/mnt/efs"
SVC_ACCT="<>"

echo "Mounting EFS on Cribl Leader nodes"

# Install the NFS client
sudo yum -y install nfs-utils

# Create mount directory
mkdir -p $MOUNT_POINT

# Start the NFS service
sudo service nfs-server start

# Mount file system
sudo mount -t nfs -o relatime,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFS_DNS_NAME:/ $MOUNT_POINT

# Add to fstab
echo "$EFS_DNS_NAME:/ $MOUNT_POINT nfs4 defaults,_netdev,nofail,relatime 0 0" >> /etc/fstab

# verify
df -h -t nfs4

sudo chown -R $SVC_ACCT:$SVC_ACCT $MOUNT_POINT

echo "Mounting EFS: Done"
