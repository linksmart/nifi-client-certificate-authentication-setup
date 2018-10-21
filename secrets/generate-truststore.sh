#!/bin/ash -e

DNAME=$1
PSWD=$2
PKSC12_PSWD=$3

echo "password: $PSWD"

echo "Generating truststore"
# Generate a JKS keystore first
keytool -genkey -keyalg RSA -alias client -keystore client_keystore.jks -keypass "$PSWD" -storepass "$PSWD" -validity 365 -keysize 4096 -dname "$DNAME"

# Export certificate and put it into truststore
keytool -export -keystore client_keystore.jks -alias client -file client.der -storepass "$PSWD"
keytool -import -file client.der -alias client -keystore truststore.jks -storepass "$PSWD" -noprompt

# Generate pkcs12 file from client_keystore.jks
keytool -importkeystore -srckeystore client_keystore.jks -destkeystore client.p12 \
 -srcstoretype JKS -deststoretype PKCS12 -srcstorepass "$PSWD" -deststorepass "$PKSC12_PSWD" \
 -srcalias client -destalias client

rm -f client_keystore.jks
rm -f client.der
chmod 640 client.p12
chmod 640 truststore.jks
