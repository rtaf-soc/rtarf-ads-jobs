#!/bin/bash

echo "TARGET_NS = [${TARGET_NS}]"
echo "TARGET_POD = [${TARGET_POD}]"

#TARGET_NS=ads-prod
#TARGET_POD=postgresql-ads-prod

TARGET_DIR=/tmp
SCRIPT_FILE=pg-cleanup-bitnami.bash

echo "Copying [${SCRIPT_FILE}] into pod=[${TARGET_POD}], namespace=[${TARGET_NS}]"
kubectl cp ${SCRIPT_FILE} -n ${TARGET_NS} ${TARGET_POD}:/${TARGET_DIR}/
if [ $? -ne 0 ]; then
    exit 1
fi

echo "Running [${SCRIPT_FILE}] in pod=[${TARGET_POD}], namespace=[${TARGET_NS}]"
kubectl exec -i -n ${TARGET_NS} ${TARGET_POD} -- bash ${TARGET_DIR}/${SCRIPT_FILE} "${PG_USER}"
if [ $? -ne 0 ]; then
    exit 1
fi

echo "Done running [${SCRIPT_FILE}] in pod=[${TARGET_POD}], namespace=[${TARGET_NS}]"
