#!/bin/bash -e

#-------------------------------------------
# DNAME of client certificate
# IMPORTANT: the empty space between different components is NECESSARY!
#-------------------------------------------
DNAME="CN=username, OU=NIFI"

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
NIFI_KEYSTORE_PASS=fraunhofer
NIFI_TRUSTSTORE_PASS=fraunhofer

#-------------------------------------------
# General settings
#-------------------------------------------
DOCKER_IMAGE_TAG=secure-nifi
DOCKER_CONTAINER_NAME=secure-nifi

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Do not modify the lines below!
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "------------------------------------------"
echo "Secure Nifi with cert-based authentication"
echo "------------------------------------------"

# If an old .env file exists, remove it
if [ -f ./.env ]; then
    rm -f ./.env
fi

# Check if both keystore.jks and truststore.jks exist
# If no, then offer to generate new one
if [ ! -z ./secrets/keystore.jks -o ! -z ./secrets/truststore.jks ]; then
    echo "keystore.jks or truststore.jks does not exist. Do you want to generate new one? The existing keystore.jks or truststore.jks will be overwritten (type the number before option to choose):"
    select yn in "Yes" "No"; do
        case ${yn} in
            Yes )
                # Generate certificate with Nifi toolkit
                echo "---------------------------------------------"
                echo "Generating keystore.jks, truststore.jks and client key"
                echo "---------------------------------------------"
                docker run --name dummy-toolkit apache/nifi-toolkit:1.6.0 \
                    ./bin/tls-toolkit.sh standalone \
                    -n "${NIFI_HOST}" \
                    -S "${NIFI_KEYSTORE_PASS}" \
                    -P "${NIFI_TRUSTSTORE_PASS}" \
                    -C "${DNAME}" \
                    --nifiDnSuffix "OU=Nifi" \ # TODO: make it a parameter
                    -o /opt/nifi/nifi-1.6.0/conf
                if [ $? != 0 ]; then    # If previous command failed
                    docker rm dummy-toolkitecho
                    echo "[ERROR] Keystore/truststore generation failed! "
                    echo "------ Launching aborted ------"
                    echo " "
                    exit 1
                fi
                docker cp dummy-toolkit:/opt/nifi/nifi-1.6.0/conf/. ./secrets
                docker rm dummy-toolkit
                mv  ./secrets/${NIFI_HOST} ./secrets/server
                echo "---------------------------------------------"
                echo "Keystore generation finished!"
                echo "---------------------------------------------"
                ;;
            No )
                echo "[ERROR] keystore.jks or truststore does not exist. Please provides your keystore in ./secrets, or use the provided script to generate a new one"
                echo "------ Launching aborted ------"
                echo " "
                exit 1
                ;;
        esac
    done
fi

echo "Setting up .env file..."
cat << EOF > ./.env
AUTH=tls
INITIAL_ADMIN_IDENTITY=${DNAME}
KEYSTORE_PATH=/opt/secrets/keystore.jks
KEYSTORE_TYPE=JKS
KEYSTORE_PASSWORD=${NIFI_KEYSTORE_PASS}
TRUSTSTORE_PATH=/opt/secrets/truststore.jks
TRUSTSTORE_PASSWORD=${NIFI_TRUSTSTORE_PASS}
TRUSTSTORE_TYPE=JKS
NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT}
NIFI_WEB_HTTP_HOST=${NIFI_HOST}
NIFI_REMOTE_INPUT_HOST=${NIFI_HOST}
EOF

echo "~~~~~~~~~~~~~~~~~~~~~~~"
echo "Setup is done!"
echo "~~~~~~~~~~~~~~~~~~~~~~~"
echo "You can now run:"
echo " "
echo "  docker build -t secure-nifi ."
echo " "
echo "to build the image. Then use this command to run the container:"
echo " "
echo "  docker run --name secure-nifi --env-file ./.env -p ${NIFI_PORT}:8443 --detach secure-nifi"
echo " "
echo "To visit the Nifi UI, you need to import the client key into your browser. The key file is located in:"
echo " "
echo "  ./secrets/client.p12"
echo " "
echo "After importing, you can visit https://${NIFI_HOST}:${NIFI_PORT}/nifi for the UI."
echo " "
echo "Happy flowing!"
echo " "
echo " "