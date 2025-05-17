#!/bin/bash

echo "BACKUP_NAME_PREFIX = [${BACKUP_NAME_PREFIX}]"

NAME_PREFIX=${BACKUP_NAME_PREFIX}
EXT=${EXTENSION}

DST_DIR=/tmp
TS=$(date +%Y%m%d_%H%M%S)
DMP_FILE=${NAME_PREFIX}-${EXT}-backup-${TS}.sql
BUCKET_NAME=rtarf-backup

gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
pg_dump -c --dbname="postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:5432/${PG_DATABASE}" > ${DST_DIR}/${DMP_FILE}

EXPORTED_FILE=${DST_DIR}/${DMP_FILE}
GCS_PATH_DB=gs://${BUCKET_NAME}/ads-backup/${DMP_FILE}

gsutil cp ${EXPORTED_FILE} ${GCS_PATH_DB}
