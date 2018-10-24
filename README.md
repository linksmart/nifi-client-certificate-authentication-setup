# Nifi Certificate-based Authentication Docker Setup

This repository provides configuration for setting up a secure Nifi docker container
with client-side certificate-based authentication. Using this method, only 
browsers with the trusted client certificate can visit the Nifi UI. Username-password authentication is not allowed.

## Quick Start
Run the setup script to generate necessary configurations:
```
./setup.sh -n host-01 -p 8443 --new-keystore --new-truststore -c "CN=admin, OU=nifi" -s "CN=host-01,OU=nifi"

    USAGE: ./setup.sh [OPTIONS] [ARGUMENTS]

    EXAMPLE: ./setup.sh -n host-01 -p 8443 --new-keystore --new-truststore -c "CN=admin, OU=nifi" -s "CN=host-01,OU=nifi"

    OPTIONS:
    
        -h, --help:               Show the help message.
        -n, --hostname HOSTNAME:  Required. The hostname of machine hosting the Nifi container.
        -p, --port PORT:          Required. The forwarded port to the Nifi UI.
        --keystore FILE:          Optional. The keystore file to be used in Nifi. If this argument is set, --keypass must also be set.
        --new-keystore:           Optional. Create new keystore. Either this flag or --keystore must be specified.
        --keypass PASSWORD:       Optional. The password to specified keystore or the newly generated one. Must be specified when --keystore is set and must match the password of the specified keystore file. If not specified, a random one will be used.
        --truststore FILE:        Optional. The truststore file to be used in Nifi. If this argument is set, --trustpass must also be set.
        --new-truststore:         Optional. Create new truststore. Either this flag or --truststore must be specified.
        --trustpass PASSWORD:     Optional. The password to the specified truststore or the newly generated one. Must be specified when --truststore is set and must match the password of the specified keystore file. If not specified, a random one will be used.
        --ext-trust:              Optional. Whether to generate a truststore from the keystore, which is intended to be used by another Nifi instance to communicate securely with this one. Only effective when --new-keystore is specified.
        --ext-pass PASSWORD:      Optional. The password to the external truststore. If not specified, a random one is used.
        --client-pass PASSWORD:   Optional. The password to the client key file. If not specified, a random one is used.
        -s, --server-dn DN:       Optional. The Distinguish Name of the server certificate in keystore (Default: CN=[HOSTNAME],OU=nifi).
        -c, --client-dn DN:       Optional. The Distinguish Name of the client certificate in truststore. MUST use SPACES to separate domain components (Default: CN=user ,OU=nifi).
```
The script will will do the following for you:  
- Generate `keystore.jks` and `truststore.jks` as required;
- Generate a `external-truststore.jks` matching the `keystore.jks` as required, which is intended to be used in another Nifi instance to communicate with this one securely.
- If you ask it to generate a new `truststore.jks`, it will also generate a matching `PKCS12` file, which needs to be imported into browser to visit the Nifi UI;
- It will generate a `.env` file in repository root directory with all properly set environment variables. You need to reference this env file when you run the container.
 
After the script is run, you can now build the new Nifi image:
```bash
docker build -t secure-nifi .
```

you can run it by using the following command:
```bash
docker run --name secure-nifi --env-file ./.env -p [port]:8443 --detach secure-nifi
```
The variable `port` must match what you specified in `--port`.

After Nifi has finished starting up, you can visit Nifi with the following URL:
 ```
 https://[hostname]:[port]/nifi
 ```
 
## Advanced

#### Putting Files into Nifi
1. If you have NAR files to add to the Nifi library, simply put them into `./nifi/nars`, they'll be copied into the newly built Nifi image.  

2. If you have configurations files to add to the Nifi instance, simply put them into `./nifi/conf`. Typically, you can put in the following files:
    - `flow.xml.gz`: this file contains the current processor setup on the Nifi canvas
    - `./templates/*.xml`: template files   


## Notes
1. When you specify the `--client-dn` argument, it is 
 **IMPORTANT** to leave **EMPTY SPACES** between components! E.g. `CN=john.doe, O=Fraunhofer, C=DE`.
 The reason behind this is that the value in `--client-dn` will be used as `INITIAL_ADMIN_USER`, and it 
 must match **100%** the subject field of the generated certificate. However, when we use the value in `--client-dn` 
 to generate certificate, spaces will be inserted between components, even you don't put spaces between them.
 As a result, to keep the subject field and the `INITIAL_ADMIN_USER` match completely, spaces between components are necessary.