#!/bin/bash

POLLING_INTERVAL=5
MIN_SITE_AVAILABLE_SUCCESSES=4

get_portal_token()
{
    local portal_url=$1
    local referer=$2
    local username=$3
    local password=$4  
    
    local get_token_url="$portal_url/sharing/rest/generateToken"  
    local get_token_params="-d username=$username -d password=$password -d client=referer -d referer=$referer -d f=json"
    local get_token_response=$(curl -s -k -X POST $get_token_params $get_token_url)
  
    local token=$(echo ${get_token_response} | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
  
    if [ -z "${token}" ]; then
        echo "Unable to fetch a portal auth token."
    fi

    echo ${token}
}

function wait_until_portal_service_is_available()
{
    local portal_url=$1
    local health_check_url="$portal_url/portaladmin/?f=json"

    echo "Checking if Portal for ArcGIS service for ($portal_url) is up..."
    local response_code=$(curl -k -s -o /dev/null -w "%{http_code}" ${health_check_url})
    
    while [ ${response_code} != 200 ]; do
        echo "($response_code) - Portal for ArcGIS service for ($portal_url) is not ready, waiting..."
        sleep ${POLLING_INTERVAL}
        response_code=$(curl -k -s -o /dev/null -w "%{http_code}" ${health_check_url})
    done
}

function wait_until_portal_site_is_available()
{
    local portal_url=$1
    local health_check_url="$portal_url/portaladmin/healthCheck?f=json"
    
    wait_until_portal_service_is_available ${portal_url}

    echo "Checking if Portal for ArcGIS site for ($portal_url) is up..."
    #local response=$(curl -k -s ${health_check_url})
    local response
    local success_count=0
    local success=false

    while [ "${success_count}" -lt "${MIN_SITE_AVAILABLE_SUCCESSES}" ]; do
        response=$(curl -k -s ${health_check_url})
        #echo ${response}

        if [ "${response}" == "{\"status\":\"success\"}" ]; then
            ((success_count++))
            echo "Portal for ArcGIS site check for ($portal_url) is successful, (${success_count}/${MIN_SITE_AVAILABLE_SUCCESSES}) consecutive successes."
        else
            success_count=0
            echo "Portal for ArcGIS site for ($portal_url) is not ready, waiting..."
        fi
        
        sleep ${POLLING_INTERVAL}
    done

    echo "Portal for ArcGIS site for ($portal_url) is up."
}

update_portal_system_properties()
{
    local portal_url=$1
    local username=$2
    local password=$3
    local web_context_url=$4
    local private_portal_url=$5
    
    local referer="$portal_url"
    local token=$(get_portal_token $portal_url $referer $username $password)
    
    local portal_properties=""
    if [ ! -z "$private_portal_url" ]; then
        portal_properties="\"privatePortalURL\":\"$private_portal_url\""
    fi

    if [ ! -z "$web_context_url" ]; then
        if [ ! -z "$portal_properties" ]; then
            portal_properties=${portal_properties} + "," + "\"WebContextURL\":\"$web_context_url\""
        else
            portal_properties="\"WebContextURL\":\"$web_context_url\""
        fi
    fi

    echo "Updating portal properties..."
    echo "Properties: ${portal_properties}"
    echo ""
    
    local update_properties_url="$portal_url/portaladmin/system/properties/update?token=$token&referer=$referer&f=json"
    local update_properties_params="properties={$portal_properties}"
    local update_properties_response=$(curl -s -k -X POST $update_properties_url -H 'Referer: '$referer -d $update_properties_params)
    
    echo $update_properties_response
    echo ""  
}

function federate_server()
{
    local portal_url=$1
    local portal_username=$2
    local portal_password=$3
    local server_url=$4
    local server_admin_url=$5
    local server_username=$6
    local server_password=$7

    local referer="$portal_url"
    local token=$(get_portal_token $portal_url $referer $portal_username $portal_password)

    local federate_server_url="$portal_url/portaladmin/federation/servers/federate?token=$token&referer=$referer&f=json"
    local federate_server_params="-d url=$server_url -d adminUrl=$server_admin_url -d username=$server_username -d password=$server_password -d client=referer -d referer=$referer -d f=json"
    local federate_server_response=$(curl -s -k -X POST $federate_server_url -H 'Referer: '$referer $federate_server_params)

    local server_id=$(echo ${federate_server_response} | grep -o '"serverId":"[^"]*' | grep -o '[^"]*$')
    echo $server_id
}

function update_federated_server_role()
{
    local portal_url=$1
    local portal_username=$2
    local portal_password=$3
    local server_id=$4
    
    # FEDERATED_SERVER | FEDERATED_SERVER_WITH_RESTRICTED_PUBLISHING | HOSTING_SERVER
    local server_role=$5
    
    # RasterAnalytics | ImageHosting | NotebookServer (Introduced at 10.8) | 
    # MissionServer (Introduced at 10.8) | WorkflowManager (Introduced at 10.8.1) | 
    # KnowledgeServer (Introduced at 10.9.1) | GeoAnalytics (Deprecated at 11.4)
    local server_function=$6

    local referer="$portal_url"
    local token=$(get_portal_token $portal_url $referer $portal_username $portal_password)

    local update_server_url="$portal_url/portaladmin/federation/servers/$server_id/update?token=$token&referer=$referer&f=json"
    local update_server_params="-d serverRole=$server_role -d serverFunction=$server_function -d client=referer -d token=$token -d referer=$referer -d f=json"
    local update_server_response=$(curl -s -k -X POST $update_server_url -H 'Referer: '$referer $update_server_params)
    
    echo $update_server_response
    echo ""
}

function get_portal_web_adaptors()
{
    local portal_url=$1
    local username=$2
    local password=$3

    local referer="$portal_url"
    local token=$(get_portal_token $portal_url $referer $username $password)

    local web_adaptors_url="$portal_url/portaladmin/system/webadaptors?token=$token&f=json"
    local web_adaptors_response=$(curl -s -k -X GET $web_adaptors_url -H 'Referer: '$referer)

    echo $web_adaptors_response
}