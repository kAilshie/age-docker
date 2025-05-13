#!/bin/bash

PROG=`basename $0`
SDIR=`dirname $0`

WAIT_AFTER_START=false
EXIT_AFTER_STOP=true

source ${SDIR}/all-utils.sh ${SDIR}

function apply_geoevent_volume_mappings()
{    
    echo "Applying GeoEvent volume mappings..."

    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/home/arcgis/.esri /home/arcgis/.esri GeoEvent-Gateway
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/home/arcgis/.esri /home/arcgis/.esri GeoEvent
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/GeoEvent ${GEOEVENT_ROOT_DIR} data
    apply_volume_mapping ${VOLUME_ROOT_DIR}/$(hostname)/config/GeoEvent ${GEOEVENT_ROOT_DIR} deploy
}

function start_geoevent_server()
{
    wait_until_server_site_is_available $(hostname -f)

    # If a portal url env variable is set then geoevent will wait for the portal
    # to be available before starting itself.
    if [ ! -z "$PORTAL_URL" ]; then 
        wait_until_portal_site_is_available $PORTAL_URL
    fi

    ${AGSSERVER_ROOT_DIR}/GeoEvent/gateway/bin/ArcGISGeoEventGateway-service start
    sleep 2
    ${AGSSERVER_ROOT_DIR}/GeoEvent/bin/ArcGISGeoEvent-service start

    echo "GeoEvent Server Started."
}

function stop_geoevent_server()
{
    echo "Stopping GeoEvent Server..."
    ${AGSSERVER_ROOT_DIR}/GeoEvent/bin/ArcGISGeoEvent-service stop

    sleep 2

    echo "Stopping GeoEvent Gateway..."
    ${AGSSERVER_ROOT_DIR}/GeoEvent/gateway/bin/ArcGISGeoEventGateway-service stop

    stop_server
}

main_geoevent()
{
    apply_geoevent_volume_mappings
    start_geoevent_server
    wait_forever
}

source ${AGSSERVER_ROOT_DIR}/entrypoint.sh

trap stop_geoevent_server SIGTERM SIGINT EXIT 

main_geoevent