#!/bin/bash
#Absolute path to this script
SCRIPT=$(readlink -f $0)
#Absolute path this script is in
SCRIPTPATH=$(dirname $SCRIPT)

cd $SCRIPTPATH
source vars

test -z ${KEY} && { echo "KEY variable is not defined."; exit 1; }
test -z ${SECRETS_ARCHIVE_PASSPHRASE} && { echo "SECRETS_ARCHIVE_PASSPHRASE variable is not defined."; exit 1; }
test -z $1 || SCRIPT="$1"
test -z $2 || HOST="_$2"
test -z $3 || INSTANCE="_$3"

USER=$(whoami)

if ! test -f ~/secrets.tar.gz.enc
then
    curl -o ~/secrets.tar.gz.enc "https://${CLOUD_SERVER}/s/${KEY}/download?path=%2F&files=secrets.tar.gz.enc"
    if ! test -f ~/secrets.tar.gz.enc
    then
        echo "ERROR: ~/secrets.tar.gz.enc not found, exiting."
        exit 1
    fi
fi
openssl enc -aes-256-cbc -md md5 -pass env:SECRETS_ARCHIVE_PASSPHRASE -d -in ~/secrets.tar.gz.enc \
 | sudo tar -zxv --strip 2 secrets/docker-duplicity-stack${HOST}${INSTANCE}/mail_credentials.json \
 secrets/docker-duplicity-stack${HOST}${INSTANCE}/nextcloud_password.sh \
 secrets/bootstrap/id_rsa secrets/bootstrap/id_rsa.pub \
 || { echo "Could not extract from secrets archive, exiting."; rm -f ~/secrets.tar.gz.enc; exit 1; }

sudo chown root:root mail_credentials.json
sudo chown $USER:$USER nextcloud_password.sh
sudo chmod 400 nextcloud_password.sh mail_credentials.json

sudo chown root. id_rsa id_rsa.pub config
sudo chmod 400 id_rsa id_rsa.pub config

cd ~
test -f ~/openrc.sh || openssl enc -aes-256-cbc -md md5 -pass env:SECRETS_ARCHIVE_PASSPHRASE -d -in ~/secrets.tar.gz.enc \
| sudo tar -zxv --strip 2 secrets/bootstrap/openrc.sh \
&& sudo chmod 500 ~/openrc.sh \
&& sudo chown $USER:$USER ~/openrc.sh

test -f ~/openrc.sh || { echo "ERROR: ~/openrc.sh not found, exiting."; exit 1; }
source ~/openrc.sh
cd $SCRIPTPATH

source nextcloud_password.sh

cd ~
test -d ~/env_py3 || { sudo virtualenv env_py3 -p /usr/bin/python3; sudo ~/env_py3/bin/pip install python-openstackclient; }
cd $SCRIPTPATH
INSTANCE_OPENSTACK=$(~/env_py3/bin/openstack server show -c id --format value $(hostname))
sudo mkdir -p /mnt/cloud
mountpoint -q /mnt/cloud || \
echo -n $NEXTCLOUD_PASSWORD | sudo -E mount -t davfs https://${CLOUD_SERVER}/remote.php/webdav/ /mnt/cloud/ -o uid=yohan,gid=yohan,username=$NEXTCLOUD_USER || exit 1
VOLUME=tmp_duplicity_workdir
sudo mkdir -p /mnt/volumes/${VOLUME}
if ! mountpoint -q /mnt/volumes/${VOLUME}
then
     ~/env_py3/bin/openstack volume create ${VOLUME} --size 20 --type high-speed || exit 1
     VOLUME_ID=$(~/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
     test -e /dev/disk/by-id/*${VOLUME_ID:0:20} || nova volume-attach $INSTANCE_OPENSTACK $VOLUME_ID auto
     sleep 3
     sudo mkfs.ext4 -F /dev/disk/by-id/*${VOLUME_ID:0:20}
     sudo mount /dev/disk/by-id/*${VOLUME_ID:0:20} /mnt/volumes/${VOLUME} || exit 1
     sudo mkdir -p /mnt/volumes/${VOLUME}/data
fi
VOLUME=duplicity_cache
sudo mkdir -p /mnt/volumes/${VOLUME}
if ! mountpoint -q /mnt/volumes/${VOLUME}
then
     ~/env_py3/bin/openstack volume create ${VOLUME} --size 5 --type high-speed || exit 1
     VOLUME_ID=$(~/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
     test -e /dev/disk/by-id/*${VOLUME_ID:0:20} || nova volume-attach $INSTANCE_OPENSTACK $VOLUME_ID auto
     sleep 3
     sudo mount /dev/disk/by-id/*${VOLUME_ID:0:20} /mnt/volumes/${VOLUME} \
       || sudo mkfs.ext4 -F /dev/disk/by-id/*${VOLUME_ID:0:20}
     mountpoint -q /mnt/volumes/${VOLUME} || sudo mount /dev/disk/by-id/*${VOLUME_ID:0:20} /mnt/volumes/${VOLUME} || exit 1
     sudo mkdir -p /mnt/volumes/${VOLUME}/data
fi

# --force-recreate is used to recreate container when crontab file has changed
CONTAINER=duplicity
IMAGE=duplicity
REPO=docker-duplicity
unset VERSION_DUPLICITY
export VERSION_DUPLICITY=$(git ls-remote https://${GIT_SERVER}/yohan/${REPO}.git| head -1 | cut -f 1|cut -c -10)

mkdir -p ~/build
git clone https://${GIT_SERVER}/yohan/${REPO}.git ~/build/${REPO}
sudo docker build -t ${IMAGE}:$VERSION_DUPLICITY ~/build/${REPO}
rm -rf ~/build

export SCRIPT
export OS_REGION_NAME=GRA
sudo -E bash -c 'docker-compose up --force-recreate' || { echo "ERROR: docker-compose up failed."; exit 1; }
# We cannot remove the secrets files or restarting the container would become impossible
#rm -f crontab debian.cnf
