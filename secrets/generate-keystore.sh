#!/bin/ash

DNAME=$1
PSWD=$2

echo "Generating new keystore for DN: $DNAME"

keytool -genkey -keyalg RSA -alias nifi -keystore keystore.jks -keypass "$PSWD" -storepass "$PSWD" -validity 365 -keysize 4096 -dname "$DNAME"
chmod 640 keystore.jks

