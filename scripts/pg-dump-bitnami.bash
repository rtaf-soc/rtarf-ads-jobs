#!/bin/bash

POSTGRES_USER=$1
OUT_FILE_NAME=$2
TARGET_DIR=$3
EXCLUDE_FLAG=$4

DB=${POSTGRES_DB}
if [ -z "${DB}" ]; then
    DB=${POSTGRES_DATABASE}
fi

FLAG1=${EXCLUDE_FLAG}
if [ -z "${FLAG1}" ]; then
    FLAG1=""
else
    FLAG1="--exclude-table-data='public.\"LogAggregates\"'"
fi

echo "In [pg-dump-bitnami.bash]"

echo "POSTGRES_USER=[${POSTGRES_USER}]"
echo "OUT_FILE_NAME=[${OUT_FILE_NAME}]"
echo "TARGET_DIR=[${TARGET_DIR}]"
echo "DB=[${DB}]"
echo "FLAG1=[${FLAG1}]"

cd ${TARGET_DIR}
# Delete the previous backup file
rm -f *.sql *.gz
pg_dump -c --no-owner ${FLAG1} --dbname="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${DB}" > ${OUT_FILE_NAME}
gzip ${OUT_FILE_NAME}
