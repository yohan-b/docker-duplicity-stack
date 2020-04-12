#!/bin/bash
set -x

DIRECTORY=/mnt/volumes/tmp_duplicity_workdir/data
ARCHIVE_DIR=/mnt/volumes/duplicity_cache/data
cd ${DIRECTORY}

export SWIFT_USERNAME=$OS_USERNAME
export SWIFT_PASSWORD=$OS_PASSWORD
export SWIFT_AUTHURL=$OS_AUTH_URL
export SWIFT_AUTHVERSION=$OS_IDENTITY_API_VERSION
export SWIFT_TENANTNAME=$OS_TENANT_NAME
export SWIFT_REGIONNAME=$OS_REGION_NAME
export PASSPHRASE=$DUPLICITY_PASSPHRASE

duplicity --num-retries 3 --full-if-older-than 1M --progress \
    --archive-dir ${ARCHIVE_DIR} --name backup_ovh1 \
    --allow-source-mismatch \
    --include /mnt/volumes/elasticsearch_data \
    --include /mnt/volumes/gogs_data \
    --include /mnt/volumes/mail_data \
    --include /mnt/volumes/mysql-server_dumps \
    --include /mnt/volumes/nextcloud \
    --include /mnt/volumes/reverse-proxy_conf \
    --include /mnt/volumes/reverse-proxy_conf_enabled \
    --include /mnt/volumes/reverse-proxy_letsencrypt \
    --include /mnt/volumes/scuttle_code \
    --include /mnt/volumes/scuttle_php5-fpm_conf \
    --exclude '**' /mnt/volumes swift://backup_ovh1
duplicity remove-older-than 2M --archive-dir ${ARCHIVE_DIR} --name backup_ovh1 --allow-source-mismatch --force swift://backup_ovh1
