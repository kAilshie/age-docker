#!/bin/bash

PROG=`basename $0`
SDIR=`dirname $0`

source ${SDIR}/all-utils.sh ${SDIR}

function apply_volume_mappings()
{    
    echo "Applying volume mappings..."

    if [ ! -d "$VOLUME_ROOT_DIR/$(hostname)" ]; then
        mkdir -p ${VOLUME_ROOT_DIR}/$(hostname)
    fi

    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config ${DATASTORE_ROOT_DIR} etc
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework ${DATASTORE_ROOT_DIR}/framework etc
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework/runtime/tomcat ${DATASTORE_ROOT_DIR}/framework/runtime/tomcat conf    
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname) ${DATASTORE_ROOT_DIR}/usr arcgisdatastore
}

function configure_datastores()
{
    if [ ! -f "${DATASTORE_ROOT_DIR}/usr/arcgisdatastore/etc/arcgis-data-store-config.json" ]; then
        echo "No ArcGIS Datastore configuration detected, configurating data store(s)..."
        
        wait_until_server_site_is_available ${HOSTING_SERVER_FQDN}
        # wait and try again after server is up just in case it immediately restarts 
        # due to its own automation workflows.
        sleep 30
        wait_until_server_site_is_available ${HOSTING_SERVER_FQDN}
        
        ${DATASTORE_ROOT_DIR}/tools/configuredatastore.sh https://${HOSTING_SERVER_FQDN}:6443/arcgis ${PSA_USERNAME} ${PSA_PASSWORD} ${DATASTORE_ROOT_DIR}/usr/arcgisdatastore --stores ${DATA_STORES}

        if [[ $DATA_STORES =~ "relational" ]]; then
            add_hosting_server_to_allowed_connections
        fi
    else
        echo "Existing ArcGIS Datastore configuration detected, skipping config."
    fi    
}

function add_hosting_server_to_allowed_connections()
{
    echo "Added hosting server to managed database connections on relation datastore..."

    local managedDBInfo=$($DATASTORE_ROOT_DIR/tools/listmanageduser.sh | awk "/Managed user for relational data store/{found=1} found" | head --lines 4 | tail --lines 1)
    local managedUsername=$(echo $managedDBInfo | cut -f 1 -d ' ')
    local managedDBName=$(echo $managedDBInfo | cut -f 3 -d ' ')

    ${DATASTORE_ROOT_DIR}/tools/allowconnection.sh ${HOSTING_SERVER_FQDN} ${managedUsername} ${managedDBName}
}

function wait_for_datastore_service()
{
    echo "Checking if datastore service is up..."
    local response_code=$(curl -k -s -o /dev/null -w "%{http_code}" https://$(hostname -f):2443/arcgis/datastoreadmin/?f=json)
    
    while [ ${response_code} != 200 ]; do
        echo "Response code: ${response_code}"
        echo "Waiting for datastore service to be ready..."
        sleep 5
        response_code=$(curl -k -s -o /dev/null -w "%{http_code}" https://$(hostname -f):2443/arcgis/datastoreadmin/?f=json)
    done
}

function start_datastore()
{
    echo "Starting ArcGIS Data Store..."
    ${DATASTORE_ROOT_DIR}/startdatastore.sh
}

function stop_datastore()
{
    echo "Stopping ArcGIS Data Store..."
    ${DATASTORE_ROOT_DIR}/stopdatastore.sh
    exit 0
}

main()
{
    apply_volume_mappings
    start_datastore
    wait_for_datastore_service
    configure_datastores
    add_hosting_server_to_allowed_connections

    echo "ArcGIS Datastore is ready on host($(hostname -f))."

    wait_forever
}

trap stop_datastore SIGTERM SIGINT EXIT 

main
