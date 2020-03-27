#!/bin/bash
source ~/openrc.sh
INSTANCE=$(~/env_py3/bin/openstack server show -c id --format value $(hostname))
VOLUME=tmp_duplicity_workdir

sudo docker-compose kill -s SIGTERM
COUNT=1
ATTEMPT=0

while [ $COUNT -ne 0 ] && [ $ATTEMPT -lt 10 ]
do
    sleep 1
    COUNT=$(sudo docker-compose top | wc -l)
    ATTEMPT=$(( $ATTEMPT + 1 ))
done

if [ $COUNT -eq 0 ]
then
    sudo docker-compose down
else
    echo "ERROR: Some containers are still running"
    sudo docker-compose ps
    exit 1
fi
sudo umount /mnt/cloud
sudo umount /mnt/volumes/${VOLUME}
mountpoint -q /mnt/volumes/${VOLUME} && exit 1
VOLUME_ID=$(~/env_py3/bin/openstack volume show ${VOLUME} -c id --format value)
nova volume-detach $INSTANCE $VOLUME_ID
~/env_py3/bin/openstack volume delete ${VOLUME}

