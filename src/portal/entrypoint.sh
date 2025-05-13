#!/bin/bash

PROG=`basename $0`
SDIR=`dirname $0`

source ${SDIR}/all-utils.sh ${SDIR}

# Creates directories within the persistence volume directory, moves files/directories
# from the container fs to the volume, deletes files/directories within the container
# if they conflict with data in the volume and symlinks files/directories in the 
# volume to the corresponding location in the container the ArCGIS software expects
# it be in.
function apply_volume_mappings()
{    
    echo "Applying volume mappings..."

    if [ ! -d "$VOLUME_ROOT_DIR/$(hostname)" ]; then
        mkdir -p ${VOLUME_ROOT_DIR}/$(hostname)
    fi

    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/etc ${PORTAL_ROOT_DIR}/etc ssl
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework ${PORTAL_ROOT_DIR}/framework etc
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework/runtime ${PORTAL_ROOT_DIR}/framework/runtime ds
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework/runtime/tomcat ${PORTAL_ROOT_DIR}/framework/runtime/tomcat conf
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/framework/webapps ${PORTAL_ROOT_DIR}/framework/webapps arcgis#sharing
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/tools ${PORTAL_ROOT_DIR}/tools indexer
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname) ${PORTAL_ROOT_DIR}/usr arcgisportal
}

function create_portal()
{
     if [ ! -f "${PORTAL_ROOT_DIR}/framework/etc/config-store-connection.json" ]; then
        echo "No portal site detected, creating new site."
        ${PORTAL_ROOT_DIR}/tools/createportal/createportal.sh -fn ${PORTAL_FIRST_NAME} -ln ${PORTAL_LAST_NAME} -u ${PSA_USERNAME} -p ${PSA_PASSWORD} -e ${PORTAL_EMAIL} -qi ${PORTAL_SECURITY_QUESTION_INDEX} -qa ${PORTAL_SECURITY_ANSWER} -d ${VOLUME_ROOT_DIR}/$(hostname)/arcgisportal/content -lf ${CONTAINER_LICENSE_DIR}/${PORTAL_LICENSE_FILE} -ut ${PSA_USERTYPE}
        
        if [ -z "$PRIVATE_PORTAL_URL" ] && [ -z "$PORTAL_WEB_CONTEXT_URL" ]; then
            echo "No portal properties to set, skipping..."
        else
            wait_until_portal_site_is_available "https://$(hostname -f):7443/arcgis"
            update_portal_system_properties "https://$(hostname -f):7443/arcgis" ${PSA_USERNAME} ${PSA_PASSWORD} ${PORTAL_WEB_CONTEXT_URL} ${PRIVATE_PORTAL_URL}
        fi

        echo ""
        echo "Create portal site process complete."
        echo ""
    else
        echo "Existing portal site detected, skipping site creation."
    fi   
}

function start_portal()
{
    ${PORTAL_ROOT_DIR}/startportal.sh
}

function stop_portal()
{
    echo "Stopping Portal for ArcGIS..."
    ${PORTAL_ROOT_DIR}/stopportal.sh
    exit 0
}

main()
{
    apply_volume_mappings
    start_portal
    wait_until_portal_service_is_available "https://$(hostname -f):7443/arcgis"
    create_portal 

    echo "Portal for ArcGIS is ready on host($(hostname -f))."

    wait_forever
}

trap stop_portal SIGTERM SIGINT EXIT 

main