#!/bin/bash

#-------------------------------------------
# DNAME of client certificate
# IMPORTANT: the empty space between different components is NECESSARY!
#-------------------------------------------
DNAME="CN=john.doe, OU=example, O=Fraunhofer FIT, L=Sankt Augustin, ST=Nordrhein Westfalen, C=DE"

#-------------------------------------------
# The hostname of the container host machine and the forwarded port to Nifi web interface
# These parameters allows a secure Nifi to accept HTTP request sent to ${NIFI_HOST}:${NIFI_PORT}, useful when Nifi is running behind a proxy or in a container.
#-------------------------------------------
NIFI_HOST=ucc-ipc-0
NIFI_PORT=5443

#-------------------------------------------
# Nifi keystore/truststore password
# The password to the keystore.jks and truststore.jks
#-------------------------------------------
NIFI_STORE_PASS=fraunhofer


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Do not modify the lines below!
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "========================================"
echo "Starting a secure Nifi instance with certificate-based authentication"
echo "========================================"


# Add certificate to truststore
docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
    -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
    /usr/src/secrets/generate-truststore.sh \
    "${DNAME}" "${NIFI_STORE_PASS}"


if [ ! -f ./secrets/keystore.jks ]; then
    echo "[ERROR] keystore.jks is missing in ./secrets"
    echo "Launching aborted"
    exit 1
fi

docker run --name secure-nifi -p ${NIFI_PORT}:8443 \
    -v "${PWD}/secrets:/opt/secrets" \
    -e AUTH=tls \
    -e INITIAL_ADMIN_IDENTITY="${DNAME}" \
    -e KEYSTORE_PATH=/opt/secrets/keystore.jks \
    -e KEYSTORE_TYPE=JKS \
    -e KEYSTORE_PASSWORD="${NIFI_STORE_PASS}" \
    -e TRUSTSTORE_PATH=/opt/secrets/truststore.jks \
    -e TRUSTSTORE_PASSWORD=${NIFI_STORE_PASS} \
    -e TRUSTSTORE_TYPE=JKS \
    -e NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT} \
    -e NIFI_WEB_HTTP_HOST=${NIFI_HOST} \
    -e NIFI_REMOTE_INPUT_HOST=${NIFI_HOST} \
    apache/nifi:1.6.0