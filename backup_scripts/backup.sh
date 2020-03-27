#!/bin/bash
set -x

DIRECTORY=/mnt/tmp_duplicity_workdir
ARCHIVE_DIR=/mnt/duplicity_cache
cd ${DIRECTORY}

export SWIFT_USERNAME=$OS_USERNAME
export SWIFT_PASSWORD=$OS_PASSWORD
export SWIFT_AUTHURL=$OS_AUTH_URL
export SWIFT_AUTHVERSION=$OS_IDENTITY_API_VERSION
export SWIFT_TENANTNAME=$OS_TENANT_NAME
export SWIFT_REGIONNAME=$OS_REGION_NAME
export PASSPHRASE=$DUPLICITY_PASSPHRASE

duplicity --num-retries 3 --full-if-older-than 1M --progress --archive-dir ${ARCHIVE_DIR} --name test --allow-source-mismatch /usr swift://Backup
duplicity remove-older-than 2M --archive-dir ${ARCHIVE_DIR} --name test --allow-source-mismatch --force swift://Backup
