#!/bin/bash

POSTGRES_USER=$1

DB=${POSTGRES_DB}
if [ -z "${DB}" ]; then
    DB=${POSTGRES_DATABASE}
fi

echo "In [pg-dump-bitnami.bash]"

echo "POSTGRES_USER=[${POSTGRES_USER}]"
echo "DB=[${DB}]"
echo "FLAG1=[${FLAG1}]"

psql --dbname="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${DB}" -c \
    'DELETE FROM "LogAggregates" WHERE event_date < (CURRENT_DATE - INTERVAL '\''30 days'\'');'
