#!/bin/bash

PROG=`basename $0`
SDIR=`dirname $0`

WAIT_AFTER_START=${WAIT_AFTER_START:-true}
EXIT_AFTER_STOP=true
FEDERATE_RETRY_ATTEMPTS=5
 
source ${SDIR}/all-utils.sh ${SDIR}

function apply_volume_mappings()
{    
    echo "Applying volume mappings..."

    if [ ! -d "$VOLUME_ROOT_DIR/$(hostname)" ]; then
        mkdir -p ${VOLUME_ROOT_DIR}/$(hostname)
    fi

    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config ${AGSSERVER_ROOT_DIR} DatabaseSupport
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework ${AGSSERVER_ROOT_DIR}/framework etc
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework/runtime/tomcat ${AGSSERVER_ROOT_DIR}/framework/runtime/tomcat conf    
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname) ${AGSSERVER_ROOT_DIR}/usr arcgisserver
}

function license_server()
{
    echo "Authorizing ArcGIS Server..."
    
    local server_licenses=${SERVER_LICENSE_FILE}
    IFS=',' read -r -a server_licenses <<< "$SERVER_LICENSE_FILE"

    for server_license in "${server_licenses[@]}"; do
        ${AGSSERVER_ROOT_DIR}/tools/authorizeSoftware -f ${CONTAINER_LICENSE_DIR}/${server_license}
    done

    #${AGSSERVER_ROOT_DIR}/tools/authorizeSoftware -f ${CONTAINER_LICENSE_DIR}/${SERVER_LICENSE_FILE}
}

function create_site()
{
    if [ ! -f "${AGSSERVER_ROOT_DIR}/framework/etc/config-store-connection.xml" ]; then
        echo "No ArcGIS Server site detected, creating new site."
        ${AGSSERVER_ROOT_DIR}/tools/createsite/createsite.sh -u ${PSA_USERNAME} -p ${PSA_PASSWORD} -d ${AGSSERVER_ROOT_DIR}/usr/arcgisserver/directories -c ${AGSSERVER_ROOT_DIR}/usr/arcgisserver/config-store

        if [ -z "$SERVER_WEB_CONTEXT_URL" ]; then
            echo "No server properties to set, skipping..."
        else
            wait_until_server_site_is_available $(hostname -f)
            update_server_system_properties $(hostname -f) ${PSA_USERNAME} ${PSA_PASSWORD} ${SERVER_WEB_CONTEXT_URL}
        fi
    else
        echo "Existing ArcGIS Server site detected, skipping site creation."
    fi    
}

function federate_with_portal()
{
    local server_admin_url="https://$(hostname -f):6443/arcgis"
    local server_url=""
    local server_id=""
    local attempt=0

    if [ -z "$SERVER_WEB_CONTEXT_URL" ]; then
        server_url=${server_admin_url}
    else
        server_url="$SERVER_WEB_CONTEXT_URL"
    fi

    echo "Checking existing federation status for($(hostname -f))"
    local already_federated=$(is_server_federated $(hostname -f) $PSA_USERNAME $PSA_PASSWORD)
    
    if [ "$already_federated" == true ]; then
        echo "Server site is already federated with a portal, skipping."
    else
        while [ -z "$server_id" ] && [ "$attempt" -le "$FEDERATE_RETRY_ATTEMPTS" ];
        do
            echo "Federating server site with portal($PORTAL_URL) - Attempt # $attempt of $FEDERATE_RETRY_ATTEMPTS"

            wait_until_portal_site_is_available $PORTAL_URL
            
            # wait and try again after portal is up just in case it immediately restarts 
            # due to its own automation workflows.  
            sleep 60
            wait_until_portal_site_is_available $PORTAL_URL

            server_id=$(federate_server $PORTAL_URL $PORTAL_USERNAME $PORTAL_PASSWORD $server_url $server_admin_url $PSA_USERNAME $PSA_PASSWORD)
            echo "Server ID: $server_id"
            
            attempt=$(($attempt + 1))            
        done

        if [ -z "$server_id" ]; then
            echo "No federated server ID generated after $FEDERATE_RETRY_ATTEMPTS, skipping server role update step."
        else
            update_federated_server_role $PORTAL_URL $PORTAL_USERNAME $PORTAL_PASSWORD $server_id $SERVER_ROLE $SERVER_FUNCTION
        fi
    fi
}

function start_server()
{
    echo "Starting ArcGIS Server..."
    ${AGSSERVER_ROOT_DIR}/startserver.sh
}

function stop_server()
{
    echo "Stopping ArcGIS Server..."
    ${AGSSERVER_ROOT_DIR}/stopserver.sh

    if [ "$EXIT_AFTER_STOP" == true ]; then
        exit 0
    fi
}

function restart_server()
{
    echo "Restarting ArcGIS Server..."
    
    ${AGSSERVER_ROOT_DIR}/stopserver.sh
    sleep 5
    ${AGSSERVER_ROOT_DIR}/startserver.sh
    sleep 5
    wait_until_server_site_is_available $(hostname -f)
}

main()
{
    apply_volume_mappings
    license_server
    
    start_server
    wait_until_server_service_is_available $(hostname -f)
    
    create_site

    if [ "$FEDERATE_SERVER" == true ]; then
        federate_with_portal
    else
        echo "Federate env variable not set, skipping federation process."
    fi

    echo "ArcGIS Server is ready on host($(hostname -f))."

    if [ "$WAIT_AFTER_START" == true ]; then
        wait_forever
    fi
}

trap stop_server SIGTERM SIGINT EXIT 

main
