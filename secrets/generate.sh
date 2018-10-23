#!/bin/ash -e

KEYSTORE_PSWD=$1
CLIENT_DNAME=$2
TRUSTSTORE_PSWD=$3

if [ ! -f ./secrets/keystore.jks ]; then
    echo "keystore.jks does not exist. Generating new keystore."
    read -p "Please enter the subject of cert. It typically has the form \"CN=[hostname],OU=nifi\":" SERVER_CERT_SUBJECT
    echo "---------------------------------------------"
    echo "Generating keystore with certificate: ${SERVER_CERT_SUBJECT}"
    echo "---------------------------------------------"
    keytool -genkey -keyalg RSA -alias nifi -keystore keystore.jks -keypass "${KEYSTORE_PSWD}" -storepass "${KEYSTORE_PSWD}" -validity 365 -keysize 4096 -dname "${SERVER_CERT_SUBJECT}"

    # Generate a truststore for this keystore, so that it could be easily used on other Nifi instances to communicate with this Nifi instance securely
    rm -f external.der
    rm -f external_truststore.jks
    echo -n "Generating a truststore for EXTERNAL usage from this keystore. Please provide password for this truststore: "
    read -s EXTERNAL_TRUSTSTORE_PSWD
    echo " "
    keytool -export -keystore keystore.jks -alias nifi -file external.der -storepass "${KEYSTORE_PSWD}"
    keytool -import -file external.der -alias nifi -keystore external_truststore.jks -storepass "${EXTERNAL_TRUSTSTORE_PSWD}" -noprompt

    # Clean up
    rm -f external.der
    chmod 640 keystore.jks
    chmod 640 external_truststore.jks
    echo "---------------------------------------------"
    echo "Keystore generation finished!"
    echo "---------------------------------------------"
fi

# Generate a JKS keystore first
if [ ! -f ./truststore.jks ]; then
    # Generate truststore and client key
    echo "truststore.jks does not exist. Generating new truststore.jks"
    echo "---------------------------------------------"
    echo "Generating truststore with subject field: ${CLIENT_DNAME}"
    echo "---------------------------------------------"
    # First generate a keystore
    keytool -genkey -keyalg RSA -alias client -keystore client_keystore.jks -keypass "${TRUSTSTORE_PSWD}" -storepass "${TRUSTSTORE_PSWD}" -validity 365 -keysize 4096 -dname "${CLIENT_DNAME}"

    # Export certificate and put it into truststore
    echo -n "Generating a PKCS12 file for client. Please provide password for this PCKS12 file: "
    read -s PKCS12_PSWD
    echo " "
    keytool -export -keystore client_keystore.jks -alias client -file client.der -storepass "${TRUSTSTORE_PSWD}"
    keytool -import -file client.der -alias client -keystore truststore.jks -storepass "${TRUSTSTORE_PSWD}" -noprompt

    # Generate pkcs12 file from client_keystore.jks
    keytool -importkeystore -srckeystore client_keystore.jks -destkeystore client.p12 \
      -srcstoretype JKS -deststoretype PKCS12 -srcstorepass "${TRUSTSTORE_PSWD}" -deststorepass "${PKCS12_PSWD}" -destkeypass "${PKCS12_PSWD}" \
      -srcalias client -destalias client

    # Clean up
    rm -f client_keystore.jks
    rm -f client.der
    chmod 640 client.p12
    chmod 640 truststore.jks
fi




