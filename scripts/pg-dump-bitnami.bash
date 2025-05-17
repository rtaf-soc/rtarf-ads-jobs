#!/bin/bash

POSTGRES_USER=$1
OUT_FILE_NAME=$2
TARGET_DIR=$3
EXCLUDE_TABS=public.LogAggregates
DB=${POSTGRES_DB}

if [ -z "${DB}" ]; then
    DB=${POSTGRES_DATABASE}
fi

cd ${TARGET_DIR}
pg_dump -c --dbname="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${DB}" > ${OUT_FILE_NAME}
