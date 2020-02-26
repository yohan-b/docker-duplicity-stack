#!/bin/bash

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
    sudo docker-compose stop
    exit 0
else
    echo "ERROR: Some containers are still running"
    sudo docker-compose ps
    exit 1
fi
