# Nifi Certificate-based Authentication Setup

This repository provides configuration for setting up a secure Nifi instance
with client-side certificate-based authentication. Using this method, only 
browsers with the trusted client certificate can visit the Nifi UI. Username-password authentication is not allowed.

## Quick Start
Run the setup script to generate necessary configurations. You can modify some parameters
inside this script:
```
./setup.sh
```
The script will will do the following for you:  
- If no `truststore.jks` exists inside `./secrets`, it will automatically generate a truststore, as well as a `PKCS12` file, which needs to be imported into browser to visit the Nifi UI;
- If no `keystore.jks` exists inside `./secrets`, it will prompt you to generate one with self-signed certificate;
- It will generate a `.env` file in repository root directory with all properly set environment variables. You need to reference this env file when you run the container.
 
After the script is run, you can now build the new Nifi image:
```bash
docker build -t secure-nifi .
```

you can run it by using the following command:
```bash
docker run --name secure-nifi --env-file ./.env -p [port]:8443 --detach secure-nifi
```
The variable `port` must match the one you specified in `./setup.sh`  

After Nifi has finished starting up, you can visit Nifi with the following URL:
 ```
 https://[hostname]:[port]/nifi
 ```
 
## Advanced

#### Putting Files into Nifi
1. If you have NAR files to add to the Nifi library, simply put them into `./nifi/nars`, they'll be copied into the newly built image in build time.  

2. If you have configurations files to add to the Nifi instance, simply put them into `./nifi/conf`. Typically, you can put in the following files:
    - `flow.xml.gz`: this file contains the current processor setup on the Nifi canvas
    - `./templates/*.xml`: template files   

#### Security
1. You can provide your own keystore and truststore. Just name them `keystore.jks` and `truststore.jks` respectively and put them into `./nifi/screts`. Then follow the quick start instruction.

2. The repository also comes with scripts to help you import existing cert file into truststore. Put your cert file (`DER` format) into `./secrets` and run the following command:
    ```bash
    docker run -it --rm -v "$PWD/secrets":/usr/src/secrets \
        -w /usr/src/secrets --user ${UID} openjdk:8-alpine \
        /usr/src/secrets/import-certificates.sh \
        [cert file name] [truststore password]
    ```
    The above command will generate the `truststore.jks` in `./secrets`.


## Notes
1. When you specify the `DNAME` environment variable in `./start.sh`, it is 
 **IMPORTANT** to leave **EMPTY SPACES** between components! E.g. `CN=john.doe, O=Fraunhofer, C=DE`.
 Why is that? Because the `DNAME` will be used as `INITIAL_ADMIN_USER`, and it 
 must match **100%** the subject field of the generated certificate. However, when we use this `DNAME` 
 to generate certificate, spaces will be inserted between components, even you don't put spaces between them.
 As a result, to keep the subject field and the `INITIAL_ADMIN_USER` match completely, we need spaces between components.