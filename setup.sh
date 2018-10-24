#!/bin/bash -e

cat << EOF
     ----------------------------------------------
    |                                              |
    |  Secure Nifi with cert-based authentication  |
    |                                              |
     ----------------------------------------------
EOF

POSITIONAL=()
while [[ $# -gt 0 ]]; do
key="$1"
    case $key in
        -h|--help)
        HELP=YES
        shift # past argument
        ;;
        -n|--hostname)
        NIFI_HOST="$2"
        shift # past argument
        shift # past value
        ;;
        -p|--port)
        NIFI_PORT="$2"
        shift # past argument
        shift # past value
        ;;
        --keystore)
        KEYSTORE="$2"
        shift # past argument
        shift # past value
        ;;
        --new-keystore)
        NEW_KEYSTORE=YES
        shift # past argument
        ;;
        --key-pass)
        KEYSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        --truststore)
        TRUSTSTORE="$2"
        shift # past argument
        shift # past value
        ;;
        --new-truststore)
        NEW_TRUSTSTORE=YES
        shift # past argument
        ;;
        --trust-pass)
        TRUSTSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        --ext-trust)
        GENERATE_EXT_TRUSTSTORE=YES
        shift # past argument
        ;;
        --ext-pass)
        EXT_TRUSTSTORE_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        -c|--client-dn)
        CLIENT_DN="$2"
        shift # past argument
        shift # past value
        ;;
        --client-pass)
        CLIENT_PASS="$2"
        shift # past argument
        shift # past value
        ;;
        -s|--server-dn)
        SERVER_DN="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

print_help(){

    cat << EOF

    This script generate appropriate configuration and keystore/truststore for a secure Nifi instance.

    USAGE: ./setup.sh [OPTIONS] [ARGUMENTS]

    Example: ./setup.sh -n host-01 -p 8443 --new-keystore --new-truststore -c "CN=admin, OU=nifi" -s "CN=host-01,OU=nifi"

    OPTIONS:

EOF
    cat << EOF | column -s"|" -t
    -h, --help:|Show the help message.
    -n, --hostname HOSTNAME:|Required. The hostname of machine hosting the Nifi container.
    -p, --port PORT:|Required. The forwarded port to the Nifi UI.
    --keystore FILE:|Optional. The keystore file to be used in Nifi. If this argument is set, --keypass must also be set.
    --new-keystore:|Optional. Create new keystore. Either this flag or --keystore must be specified.
    --keypass PASSWORD:|Optional. The password to specified keystore or the newly generated one. Must be specified when --keystore is set and must match the password of the specified keystore file. If not specified, a random one will be used.
    --truststore FILE:|Optional. The truststore file to be used in Nifi. If this argument is set, --trustpass must also be set.
    --new-truststore:|Optional. Create new truststore. Either this flag or --truststore must be specified.
    --trustpass PASSWORD:|Optional. The password to the specified truststore or the newly generated one. Must be specified when --truststore is set and must match the password of the specified keystore file. If not specified, a random one will be used.
    --ext-trust:|Optional. Whether to generate a truststore from the keystore, which is intended to be used by another Nifi instance to communicate securely with this one.
    --ext-pass PASSWORD:|Optional. The password to the external truststore. If not specified, a random one is used.
    --client-pass PASSWORD:|Optional. The password to the client key file. If not specified, a random one is used.
    -s, --server-dn DN:|Optional. The Distinguish Name of the server certificate in keystore (Default: CN=[HOSTNAME],OU=nifi).
    -c, --client-dn DN:|Optional. The Distinguish Name of the client certificate in truststore. MUST use SPACES to separate domain components (Default: CN=user ,OU=nifi).
EOF

}

gen_pass(){
    echo $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
}

# Check the correctness of arguments
if [ ! -z "${HELP}" ]; then
    print_help
    exit 0
fi
if [ -z "${NIFI_HOST}" ]; then
    echo "[ERROR] \"-n | --hostname\" is not specified "
    print_help
    exit 1
fi
if [ -z "${NIFI_PORT}" ]; then
    echo "[ERROR] \"-p | --port\" is not specified "
    print_help
    exit 1
fi
if [ ! -z "${KEYSTORE}" -a -z "${KEYSTORE_PASS}" ]; then
    echo "[ERROR] keystore specified but no keystore pass is given"
    print_help
    exit 1
fi
if [ ! -z "${TRUSTSTORE}" -a -z "${TRUSTSTORE_PASS}" ]; then
    echo "[ERROR] truststore specified but no truststore pass is given"
    print_help
    exit 1
fi
if [ -z "${KEYSTORE}" -a -z "${NEW_KEYSTORE}" ]; then
    echo "[ERROR] Either --keystore or --new-keystore must be specified"
    exit 1
fi
if [ -z "${TRUSTSTORE}" -a -z "${NEW_TRUSTSTORE}" ]; then
    echo "[ERROR] Either --truststore or --new-truststore must be specified"
    exit 1
fi
if [ ! -z "${KEYSTORE}" -a ! -f "${KEYSTORE}" ]; then
    echo "[ERROR] ${KEYSTORE} does not exist."
    exit 1
fi
if [ ! -z "${TRUSTSTORE}" -a ! -f "${TRUSTSTORE}" ]; then
    echo "[ERROR] ${TRUSTSTORE} does not exist."
    exit 1
fi

# If both --keystore and --new-keystore is specified, ignore --new-keystore
if [ ! -z "${KEYSTORE}" -a ! -z "${NEW_KEYSTORE}" ]; then
    unset NEW_KEYSTORE
fi
if [ ! -z "${TRUSTSTORE}" -a ! -z "${NEW_TRUSTSTORE}" ]; then
    unset NEW_TRUSTSTORE
fi

if [ ! -z "${NEW_KEYSTORE}" ]; then
    rm -f ./secrets/keystore.jks
fi
if [ ! -z "${NEW_TRUSTSTORE}" ]; then
    rm -f ./secrets/truststore.jks
fi

# Prepare files
if [ ! -z "${KEYSTORE}" ]; then
    mv -f "${KEYSTORE}" ./secrets/keystore.jks
fi
if [ ! -z "${TRUSTSTORE}" ]; then
    mv -f "${TRUSTSTORE}" ./secrets/truststore.jks
fi

# Give default values
: ${CLIENT_DN:="CN=user, OU=nifi"}
: ${SERVER_DN:="CN=${NIFI_HOST},OU=nifi"}
: ${KEYSTORE_PASS:=$(gen_pass)}
: ${TRUSTSTORE_PASS:=$(gen_pass)}
: ${GENERATE_EXT_TRUSTSTORE:=NO}
: ${EXT_TRUSTSTORE_PASS:=$(gen_pass)}
: ${CLIENT_PASS:=$(gen_pass)}

# Generate keystore/truststore
docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/generate.sh \
        "${SERVER_DN}" "${KEYSTORE_PASS}" \
        "${CLIENT_DN}" "${TRUSTSTORE_PASS}" \
        "${GENERATE_EXT_TRUSTSTORE}" "${EXT_TRUSTSTORE_PASS}" \
        "${CLIENT_PASS}"


echo "Setting up .env file..."
cat << EOF > ./.env
AUTH=tls
INITIAL_ADMIN_IDENTITY=${CLIENT_DN}
KEYSTORE_PATH=/opt/secrets/keystore.jks
KEYSTORE_TYPE=JKS
KEYSTORE_PASSWORD=${KEYSTORE_PASS}
TRUSTSTORE_PATH=/opt/secrets/truststore.jks
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASS}
TRUSTSTORE_TYPE=JKS
NIFI_WEB_PROXY_HOST=${NIFI_HOST}:${NIFI_PORT}
NIFI_WEB_HTTP_HOST=${NIFI_HOST}
NIFI_REMOTE_INPUT_HOST=${NIFI_HOST}
EOF

cat << EOF
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            Setup is done!
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
You can now run:

   docker build -t secure-nifi .

to build the image. Then run the container:

   docker run --name secure-nifi --env-file ./.env -p ${NIFI_PORT}:8443 --detach secure-nifi

To visit the Nifi UI, you need to import the client key into your browser. The key file is located in:

   ./secrets/client.p12

After importing, you can visit the following URL for the Nifi UI:

   https://${NIFI_HOST}:${NIFI_PORT}/nifi

Happy flowing!


EOF