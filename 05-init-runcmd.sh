#!/bin/bash

# Please review the README file before making updates

echo "===> UserData $(basename $BASH_SOURCE) Script: Start"

CRIBL_HOME="/opt/cribl"
CRIBL_VERSION="4.7.3"
CRIBL_BUILD_ID="6f48361f"
CRIBL_GITLAB_API_TOKEN=$(aws secretsmanager get-secret-value --secret-id <>/cribl_cfs_gitlab_api_token | jq -r ".SecretString")
CRIBL_AUTH_TOKEN=$(aws secretsmanager get-secret-value --secret-id <>/cribl_cfs_auth_token | jq -r ".SecretString")
SVC_ACCT="<>"
ENV_ACCT="dev"
ENV_TYPE="nonprod"

config_remove_proxy () {

    # Removing default proxy settings
    File="/etc/profile.d/proxy.sh"
    if [ -f "$File" ]; then
    rm /etc/profile.d/proxy.sh
    fi
    export http_proxy="http://<>:8080"
    export https_proxy="http://<>:8080"
    export no_proxy="127.0.0.1, <>,

}

config_init_boot () {

    echo "# Disable Transparent Huge Pages (THP)"
    sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
    sudo echo never > /sys/kernel/mm/transparent_hugepage/defrag

    echo "# Disable host-based firewall"
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    sudo systemctl stop iptables
    sudo systemctl disable iptables

    echo "# Install Python dependencies"
    sudo no_proxy=<> python3 -m pip install boto3 botocore --index https://<>/repository/pypi/ --index-url https://<>/repository/pypi/simple
    sudo chmod -R 755 /usr/local/lib /usr/local/lib64

    echo "# Downloading Cribl installer"
    aws s3 cp s3://adt-base01-<>-$ENV_ACCT-data-west1-bucket/cribl/download/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tar ~/cribl/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz
    aws s3 cp s3://adt-base01-<>-$ENV_ACCT-data-west1-bucket/cribl/download/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz.sha256 ~/cribl/

    # wget -P ~/cribl "https://cdn.cribl.io/dl/$CRIBL_VERSION/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz"
    # wget -P ~/cribl "https://cdn.cribl.io/dl/$CRIBL_VERSION/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz.sha256"

    if [[ $(cd ~/cribl; sha256sum --check --status ~/cribl/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz.sha256; echo "$?") == 0 ]]
    then
        echo "# Extract Cribl installer"
        tar zxf ~/cribl/cribl-$CRIBL_VERSION-$CRIBL_BUILD_ID-linux-x64.tgz -C /opt/
    else
        echo "Mismatch Cribl installer SHA256 checksum. Exiting..."
        exit 1
    fi

    # Determine the auth directory path
    if [[ $(hostname | cut -c1-3) == "lam" ]]
    then
        AUTH_PATH="/mnt/efs/auth"
        mkdir -p $AUTH_PATH
    elif [[ $(hostname | cut -c1-4) == "lawn" ]]
    then
        AUTH_PATH="$CRIBL_HOME/local/cribl/auth"
    else
        echo "Unable to determine auth directory path. Exiting..."
        exit 1
    fi

    echo "AUTH_PATH=$AUTH_PATH"

    mkdir -p $CRIBL_HOME/local/cribl/auth

    echo "# Cribl SSL certificate configuration"
    aws secretsmanager get-secret-value --secret-id <>/el-log-aggr-$ENV_TYPE/log-aggr-cfs-cert | jq -r ".SecretString" | sed "/^$/d" > $AUTH_PATH/el-log-aggr-$ENV_TYPE.crt
    if [ $? -eq 0 ]; then
        echo "Succeed public cert"
    else
        echo "Failed public cert"
    fi
    aws secretsmanager get-secret-value --secret-id <>/el-log-aggr-$ENV_TYPE/log-aggr-cfs-cert-key | jq -r ".SecretString" | sed "/^$/d" > $AUTH_PATH/el-log-aggr-$ENV_TYPE.key
    if [ $? -eq 0 ]; then
        echo "Succeed private cert"
    else
        echo "Failed private cert"
    fi

    # echo "# Configure Cribl secret key"
    # aws secretsmanager get-secret-value --secret-id <>/cribl_cfs_secret | jq -r ".SecretString" | sed "/^$/d" > $CRIBL_HOME/local/cribl/auth/cribl.secret


    if [[ $(hostname | cut -c1-3) == "lam" ]]
    then
        echo "# Initialize as Leader node"
        $CRIBL_HOME/bin/cribl mode-master

        echo "# Configure as Leader node"
        $CRIBL_HOME/bin/cribl mode-master -r failover -v /mnt/efs -u $CRIBL_AUTH_TOKEN -S true -c $AUTH_PATH/el-log-aggr-$ENV_TYPE.crt -k $AUTH_PATH/el-log-aggr-$ENV_TYPE.key

        $CRIBL_HOME/bin/cribl start
        echo "# Pause for 15 secs"
        sleep 15
        $CRIBL_HOME/bin/cribl stop

        cat > /mnt/efs/local/cribl/cribl.yml <<EOF
api:
  host: 0.0.0.0
  port: 9000
  disabled: false
  loginRateLimit: 2/second
  ssoRateLimit: 2/second
  scripts: false
  ssl:
    disabled: false
    privKeyPath: $AUTH_PATH/el-log-aggr-$ENV_TYPE.key
    certPath: $AUTH_PATH/el-log-aggr-$ENV_TYPE.crt
git:
  gitOps: none
  authType: basic
  autoAction: none
  timeout: 60000
  strictHostKeyChecking: true
  remote: https://gitlab.prod.nit-cicd.awscfs.frb.pvt/<>/log-aggregator/cribl-leader-$ENV_ACCT.git
  user: CRIBL_GITLAB_API_TOKEN
  password: $CRIBL_GITLAB_API_TOKEN
EOF

        echo "# Install license"
        echo "licenses:" > /mnt/efs/local/cribl/licenses.yml
        aws secretsmanager get-secret-value --secret-id <>/cribl_cfs_license | jq -r ".SecretString" | sed "s/^/  - /" >> /mnt/efs/local/cribl/licenses.yml
    
        echo "# Change ownership of Cribl NFS mount"
        sudo chown -R $SVC_ACCT:$SVC_ACCT /mnt/efs

    elif [[ $(hostname | cut -c1-4) == "lawn" ]]
    then       
        echo "# Configure as Worker node"
        $CRIBL_HOME/bin/cribl mode-worker -H el-splunk-lam.$ENV_ACCT.<>.awscfs.frb.pvt -p 4200 -u $CRIBL_AUTH_TOKEN -S true -c $AUTH_PATH/el-log-aggr-$ENV_TYPE.crt -k $AUTH_PATH/el-log-aggr-$ENV_TYPE.key

    else
        echo "The instance is not a Cribl node. Exiting..."
        exit 1
    fi

    echo "# Change ownership of Cribl home and tmp directory"
    sudo chown -R $SVC_ACCT:$SVC_ACCT $CRIBL_HOME
    sudo chown -R $SVC_ACCT:$SVC_ACCT /tmp/cribl*

    echo "# Block the cleaner"
    echo "X /tmp/cribl*" > /etc/tmpfiles.d/cribl.conf
    sudo systemctl restart systemd-tmpfiles-clean.service

    echo "# Enable Cribl to start at boot time with systemd"
    sudo $CRIBL_HOME/bin/cribl boot-start enable -m systemd -u $SVC_ACCT
    sudo systemctl enable cribl

    if [[ $(hostname | cut -c1-4) == "lawn" ]]
    then
        echo "# Add no_proxy to /etc/systemd/system/cribl.service"
        sed -i "/\[Service\]/a no_proxy=el-splunk-lam.$ENV_ACCT.<>.awscfs.frb.pvt" /etc/systemd/system/cribl.service
    fi

    echo "# Reload Cribl systemd manager configuration and start the service"
    sudo systemctl daemon-reload
    sudo systemctl start cribl
    sudo systemctl status cribl


}


# Invoking functions
config_remove_proxy
config_init_boot

