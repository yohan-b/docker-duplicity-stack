#!/bin/bash
test -z $1 || SCRIPT="$1"
test -z $2 || HOST="_$2"
test -z $3 || INSTANCE="_$3"

source ~/openrc.sh
INSTANCE=$(~/env_py3/bin/openstack server show -c id --format value $(hostname))
VOLUME=tmp_duplicity_workdir
sudo mkdir -p /mnt/volumes/${VOLUME}
if ! mountpoint -q /mnt/volumes/${VOLUME}
then
     ~/env_py3/bin/openstack volume create ${VOLUME} --size 2 --type high-speed
     VOLUME_ID=$(~/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
     test -e /dev/disk/by-id/*${VOLUME_ID:0:20} || nova volume-attach $INSTANCE $VOLUME_ID auto
     sleep 3
     sudo mkfs.ext4 -F /dev/disk/by-id/*${VOLUME_ID:0:20}
     sudo mount /dev/disk/by-id/*${VOLUME_ID:0:20} /mnt/volumes/${VOLUME} || exit 1
     sudo mkdir -p /mnt/volumes/${VOLUME}/data
fi
VOLUME=duplicity_cache
sudo mkdir -p /mnt/volumes/${VOLUME}
if ! mountpoint -q /mnt/volumes/${VOLUME}
then
     ~/env_py3/bin/openstack volume create ${VOLUME} --size 2 --type high-speed
     VOLUME_ID=$(~/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
     test -e /dev/disk/by-id/*${VOLUME_ID:0:20} || nova volume-attach $INSTANCE $VOLUME_ID auto
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
VERSION_DUPLICITY=$(git ls-remote https://git.scimetis.net/yohan/${REPO}.git| head -1 | cut -f 1|cut -c -10)

mkdir -p ~/build
git clone https://git.scimetis.net/yohan/${REPO}.git ~/build/${REPO}
sudo docker build -t ${IMAGE}:$VERSION_DUPLICITY ~/build/${REPO}

export SCRIPT
export OS_REGION_NAME=GRA

VERSION_DUPLICITY=$VERSION_DUPLICITY \
 sudo -E bash -c 'docker-compose up -d --force-recreate'
# We cannot remove the secrets files or restarting the container would become impossible
#rm -f crontab debian.cnf

rm -rf ~/build
