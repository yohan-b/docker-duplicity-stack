#!/bin/bash
set -x

DIRECTORY=/mnt/volumes/tmp_duplicity_workdir/data
ARCHIVE_DIR=/mnt/volumes/duplicity_cache/data
curl -o ${DIRECTORY}/secrets.tar.gz.enc "https://cloud.scimetis.net/s/${KEY}/download?path=%2F&files=secrets.tar.gz.enc" || { echo "ERROR: Failed to retrieve secrets archive."; exit 1; }
cd ${DIRECTORY}
openssl enc -aes-256-cbc -md md5 -pass env:SECRETS_ARCHIVE_PASSPHRASE -d -in ${DIRECTORY}/secrets.tar.gz.enc | tar -zxv
curl -o ${DIRECTORY}/Documentation.md "https://cloud.scimetis.net/s/${DOC_KEY}/download" || { echo "ERROR: Failed to retrieve documentation."; exit 1; }
if ! diff -q ${DIRECTORY}/Documentation.md ${DIRECTORY}/secrets/bootstrap/Documentation.md
then 
    mv -f ${DIRECTORY}/Documentation.md ${DIRECTORY}/secrets/bootstrap/
    tar -czvpf - -C ${DIRECTORY} secrets | openssl enc -aes-256-cbc -md md5 -pass env:SECRETS_ARCHIVE_PASSPHRASE -salt -out ${DIRECTORY}/secrets.tar.gz.enc
    echo "Secrets archive has changed. New file attached." > /root/mail
    /root/sendmail.py -a ${DIRECTORY}/secrets.tar.gz.enc /root/mail /root/mail_credentials.json
    cp -f ${DIRECTORY}/secrets.tar.gz.enc /mnt/cloud/Passwords/
fi
ssh -p2224 yohan@chez-yohan.scimetis.net "bash -c 'sudo mkdir -p /mnt/archives_critiques/secrets/ && sudo chown -R yohan. /mnt/archives_critiques/secrets/'"
FILENAME=secrets.tar.gz.enc-$(sha1sum ${DIRECTORY}/secrets.tar.gz.enc | awk -F' ' '{print $1}')
scp -P 2224 ${DIRECTORY}/secrets.tar.gz.enc yohan@chez-yohan.scimetis.net:/mnt/archives_critiques/secrets/$FILENAME
rm -rf ${DIRECTORY}/secrets* ${DIRECTORY}/Documentation.md

for name in docker-nextcloud-stack docker-reverse-proxy-stack docker-reverse-proxy docker-gogs-stack docker-mysql-stack docker-mysql systemd-mount-cinder-volume
do
    git clone https://git.scimetis.net/yohan/${name}.git ${DIRECTORY}/${name}
    tar -czf ${DIRECTORY}/${name}.tar.gz -C ${DIRECTORY} ${name}
    rm -rf ${DIRECTORY}/${name}
done

export SWIFT_USERNAME=$OS_USERNAME
export SWIFT_PASSWORD=$OS_PASSWORD
export SWIFT_AUTHURL=$OS_AUTH_URL
export SWIFT_AUTHVERSION=$OS_IDENTITY_API_VERSION
export SWIFT_TENANTNAME=$OS_TENANT_NAME
export SWIFT_REGIONNAME=$OS_REGION_NAME
export PASSPHRASE=$DUPLICITY_PASSPHRASE
duplicity --num-retries 3 --full-if-older-than 1M --progress --archive-dir ${ARCHIVE_DIR} --name bootstrap --allow-source-mismatch "${DIRECTORY}" swift://bootstrap
duplicity remove-older-than 2M --archive-dir ${ARCHIVE_DIR} --name bootstrap --allow-source-mismatch --force swift://bootstrap
