#!/bin/bash

PROG=`basename $0`
SDIR=`dirname $0`

# These values mirror the values in the default server.xml generated during 
# the image build phase. These variables should only be overridden if the 
# /usr/local/tomcat/conf/server.xml is overridden.
CERT_DIR="/opt/arcgis/certs"
CERT_FILE_NAME="certificate.pfx"
CERT_PASSWORD="Arcgis1!"
CONFIGURE_RETRY_ATTEMPTS=3

source ${SDIR}/all-utils.sh ${SDIR}

function apply_volume_mappings()
{    
    echo "Applying volume mappings..."

    if [ ! -d "$VOLUME_ROOT_DIR/$(hostname)" ]; then
        mkdir -p ${VOLUME_ROOT_DIR}/$(hostname)
    fi

    if [ ! -d "$HOME/.webadaptor" ]; then
        mkdir -p "$HOME/.webadaptor"
    fi

    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/tomcat ${TOMCAT_ROOT_DIR} conf
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/tomcat ${TOMCAT_ROOT_DIR} webapps
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config ${HOME} ".webadaptor"
}

function create_default_cert()
{
    echo "Creating default certificate..."
    openssl genrsa -out ${CERT_DIR}/privateKey.key 2048
    openssl req -new -key ${CERT_DIR}/privateKey.key -out ${CERT_DIR}/certificate.csr -subj "/CN=$(hostname -f)/O=SelfSignedCertificate" -addext "subjectAltName=DNS:$(hostname),DNS:$(hostname -f)"
    openssl x509 -req -in ${CERT_DIR}/certificate.csr -signkey ${CERT_DIR}/privateKey.key -out ${CERT_DIR}/certificate.crt -days 365
    openssl pkcs12 -export -out ${CERT_DIR}/${CERT_FILE_NAME} -inkey ${CERT_DIR}/privateKey.key -in ${CERT_DIR}/certificate.crt -passout pass:${CERT_PASSWORD}
}

function config_external_cert()
{
    echo "Configuring user supplied certificate..."
    openssl pkcs12 -in ${CONTAINER_CERT_DIR}/${WA_SERVER_CERT_FILENAME} -out ${CERT_DIR}/certificate.pem -nodes -passin pass:${WA_SERVER_CERT_PASSWORD}
    openssl pkcs12 -export -out ${CERT_DIR}/${CERT_FILE_NAME} -in ${CERT_DIR}/certificate.pem -passout pass:${CERT_PASSWORD}
}

function configure_cert()
{
    if [ -f "${CONTAINER_CERT_DIR}/${WA_SERVER_CERT_FILENAME}" ]; then
        config_external_cert
    else
        create_default_cert
    fi
}

function deploy_wars()
{
    if [ -d ${CONTAINER_WA_CONFIGS_DIR} ]; then
       for config_file in "$CONTAINER_WA_CONFIGS_DIR"/*.json; do
            if [ -e "$config_file" ]; then
                deploy_war ${config_file}
            else
                echo "No web adaptor config .json files found, skipping war deployment."
            fi
        done
    else
        echo "No web adaptor configs directory is set, skipping war deployment."
    fi
}

function deploy_war()
{
    local config_file=$1
    local context=$(jq -r '.context' $config_file)
    local war_path="${TOMCAT_ROOT_DIR}/webapps/${context}.war"

    echo "context: $context"

    if [ "$context" == "null" ]; then
        echo "the context property for ${config_file} is missing, or not set, skipping war deployment."        
    else
        if [ -e "$war_path" ]; then
            echo "war file for ${context} has already been deployed, skipping war deployment."
        else
            echo "Deploying war file for ${context}..."
            cp ${WA_ROOT_DIR}/java/arcgis.war ${war_path}
        fi 
    fi
}

function configure_web_adaptors()
{
    if [ -d ${CONTAINER_WA_CONFIGS_DIR} ]; then
       for config_file in "$CONTAINER_WA_CONFIGS_DIR"/*.json; do
            if [ -e "$config_file" ]; then
                configure_web_adaptor ${config_file}
            else
                echo "No web adaptor config .json files found, skipping web adaptor configuration."
            fi
        done
    else
        echo "No web adaptor configs directory is set, skipping web adaptor configuration."
    fi
}

function configure_web_adaptor()
{
    local config_file=$1
    local mode=$(jq -r '.mode' $config_file)

    case $mode in
        server)
            configure_server_web_adaptor $config_file
            ;;
        portal)
            configure_portal_web_adaptor $config_file
            ;;
        *)
            echo "Unsupported web adaptor mode, skipping web adaptor configure step."
            ;;
    esac    
}

function configure_server_web_adaptor()
{
    local config_file=$1
    local context=$(jq -r '.context' $config_file)
    local webAdaptorUrl="https://$(hostname -f)/$context/webadaptor"
    local mode=$(jq -r '.mode' $config_file)
    local siteFQDN=$(jq -r '.siteFQDN' $config_file)
    local username=$(jq -r '.siteUsername' $config_file)
    local password=$(jq -r '.sitePassword' $config_file)
    local adminAccess=$(jq -r '.adminAccess' $config_file)
    
    # Wait for the server site to become available
    wait_until_server_site_is_available $siteFQDN

    # Check if this web adaptor configuration has already been applied
    local is_configured=$(is_server_web_adaptor_configured $config_file)    

    # Register web adaptor
    if [ "$is_configured" == false ]; then
        echo "Registering ${context} web adaptor with ${siteFQDN}"
        local configure_result=$(${WA_ROOT_DIR}/java/tools/configurewebadaptor.sh -m ${mode} -w ${webAdaptorUrl} -g ${siteFQDN} -u ${username} -p ${password} -a ${adminAccess})
        local attempt=1
        echo "Configure Result: ${configure_result}"

        while [ "$configure_result" != "Successfully Registered." ] && [ "$attempt" -le "$CONFIGURE_RETRY_ATTEMPTS" ];
        do
            ((attempt++))
            echo "Web adaptor configuration failed for context: ${context} site: ${siteFQDN}... retrying ($attempt/$CONFIGURE_RETRY_ATTEMPTS)"
            wait_until_server_site_is_available $siteFQDN
            configure_result=$(${WA_ROOT_DIR}/java/tools/configurewebadaptor.sh -m ${mode} -w ${webAdaptorUrl} -g ${siteFQDN} -u ${username} -p ${password} -a ${adminAccess})
            echo ${configure_result}
        done
    elif [ "$is_configured" == true ]; then
        echo "web adaptor: ${context} on ${siteFQDN} is already registered, skipping configuration."
    else
        echo "Unknown registration state, skipping configuration."
    fi
}

function configure_portal_web_adaptor()
{
    local config_file=$1
    local context=$(jq -r '.context' $config_file)
    local webAdaptorUrl="https://$(hostname -f)/$context/webadaptor"
    local mode=$(jq -r '.mode' $config_file)
    local siteFQDN=$(jq -r '.siteFQDN' $config_file)
    local username=$(jq -r '.siteUsername' $config_file)
    local password=$(jq -r '.sitePassword' $config_file)
    local adminAccess=$(jq -r '.adminAccess' $config_file)
    
    # Wait for the portal site to become available
    wait_until_portal_site_is_available "https://$siteFQDN:7443/arcgis"

    # Check if this web adaptor configuration has already been applied
    local is_configured=$(is_portal_web_adaptor_configured $config_file)

    # Register web adaptor
    if [ "$is_configured" == false ]; then
        echo "Registering ${context} web adaptor with ${siteFQDN}"
        local configure_result=$(${WA_ROOT_DIR}/java/tools/configurewebadaptor.sh -m ${mode} -w ${webAdaptorUrl} -g ${siteFQDN} -u ${username} -p ${password} -a ${adminAccess})
        local attempt=1
        echo "Configure Result: ${configure_result}"

        while [ "$configure_result" != "Successfully Registered." ] && [ "$attempt" -le "$CONFIGURE_RETRY_ATTEMPTS" ];
        do
            ((attempt++))
            echo "Web adaptor configuration failed for context: ${context} site: ${siteFQDN}... retrying ($attempt/$CONFIGURE_RETRY_ATTEMPTS)"
            wait_until_portal_site_is_available "https://$siteFQDN:7443/arcgis"
            configure_result=$(${WA_ROOT_DIR}/java/tools/configurewebadaptor.sh -m ${mode} -w ${webAdaptorUrl} -g ${siteFQDN} -u ${username} -p ${password} -a ${adminAccess})
            echo ${configure_result}
        done
    elif [ "$is_configured" == true ]; then
        echo "web adaptor: ${context} on ${siteFQDN} is already registered, skipping configuration."
    else
        echo "Unknown registration state, skipping configuration."
    fi
}

function is_server_web_adaptor_configured()
{
    local is_configured=false
    local config_file=$1
    local context=$(jq -r '.context' $config_file)
    local siteFQDN=$(jq -r '.siteFQDN' $config_file)
    local username=$(jq -r '.siteUsername' $config_file)
    local password=$(jq -r '.sitePassword' $config_file)
    
    local web_adaptors_response=$(get_server_web_adaptors $siteFQDN $username $password)
    local web_adaptors_arr=$(jq -c '.webAdaptors[]' <<< "$web_adaptors_response")
    local machine_name
    local web_adaptor_url

    for web_adaptor in $web_adaptors_arr; do
        machine_name=$(echo $web_adaptor | jq -r '.machineName')
        web_adaptor_url=$(echo $web_adaptor | jq -r '.webAdaptorURL')
    done

    if [ "${web_adaptor_url##*/}" == "${context}" ] && [ $machine_name == $(hostname -f) ]; then
        is_configured=true
    fi
    echo $is_configured
}

function is_portal_web_adaptor_configured()
{
    local is_configured=false
    local config_file=$1
    local context=$(jq -r '.context' $config_file)
    local siteFQDN=$(jq -r '.siteFQDN' $config_file)
    local portal_url="https://$siteFQDN:7443/arcgis"
    local username=$(jq -r '.siteUsername' $config_file)
    local password=$(jq -r '.sitePassword' $config_file)
    
    local web_adaptors_response=$(get_portal_web_adaptors $portal_url $username $password)
    local web_adaptors_arr=$(jq -c '.webAdaptors[]' <<< "$web_adaptors_response")
    local machine_name
    local web_adaptor_url

    for web_adaptor in $web_adaptors_arr; do
        machine_name=$(echo $web_adaptor | jq -r '.machineName')
        web_adaptor_url=$(echo $web_adaptor | jq -r '.webAdaptorURL')
    done

    if [ "${web_adaptor_url##*/}" == "${context}" ] && [ $machine_name == $(hostname -f) ]; then
        is_configured=true
    fi

    echo $is_configured
}

function stop_web_server()
{
    echo "Stopping Tomcat server..."
    ${TOMCAT_ROOT_DIR}/bin/catalina.sh stop
}

function start_web_server()
{
    echo "Starting Tomcat server..."
    ${TOMCAT_ROOT_DIR}/bin/catalina.sh start
}

main()
{
    apply_volume_mappings
    deploy_wars
    configure_cert
    start_web_server
    sleep 5
    
    configure_web_adaptors

    echo "ArcGIS Web Adaptor Web Server is ready on host($(hostname -f))."

    wait_forever
}

trap stop_web_server SIGTERM SIGINT EXIT 

main