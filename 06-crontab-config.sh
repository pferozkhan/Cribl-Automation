#!/bin/bash

echo "===> UserData $(basename $BASH_SOURCE) Script: Start"
# CONFIG_CRONTAB="false"

# if [[ "$CONFIG_CRONTAB" = true ]]
# then
#     echo "# Creating crontab for /var/lib/cloud/instance/scripts/4-init-runcmd.sh"
#     (crontab -l; echo "@reboot bash -lc /var/lib/cloud/instance/scripts/4-init-runcmd.sh") | awk '!x[$0]++' | crontab -
# fi

