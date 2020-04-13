#!/bin/bash
set -x

DIRECTORY=/mnt/volumes/tmp_duplicity_workdir/data
ARCHIVE_DIR=/mnt/volumes/duplicity_cache/data
cd /mnt/volumes

for name in elasticsearch_data gogs_data mail_data nextcloud reverse-proxy_conf reverse-proxy_conf_enabled reverse-proxy_letsencrypt scuttle_code scuttle_php5-fpm_conf
do
    tar -czf ${DIRECTORY}/${name}.tar.gz -C /mnt/volumes ${name} || exit 1
done

name="mysql-server_dumps"
name_mysql_dump=$(ls -tr ${name}/data/mysql_dump-mysql_*|tail -n1)
name_dbs_dump=$(ls -tr ${name}/data/mysql_dump_*|tail -n1)
tar -czf ${DIRECTORY}/${name}.tar.gz -C /mnt/volumes ${name_mysql_dump} ${name_dbs_dump} || exit 1

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
    ${DIRECTORY} swift://backup_ovh1 || exit 1
duplicity remove-older-than 2M --archive-dir ${ARCHIVE_DIR} --name backup_ovh1 --allow-source-mismatch --force swift://backup_ovh1
