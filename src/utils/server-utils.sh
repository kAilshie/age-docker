#!/bin/bash

POLLING_INTERVAL=5

get_server_token()
{
    local host=$1
    local referer=$2
    local username=$3
    local password=$4

    local get_token_url="https://$host:6443/arcgis/admin/generateToken"  
    local get_token_params="-d username=$username -d password=$password -d client=referer -d referer=$referer -d f=json"
    local get_token_response=$(curl -s -k -X POST $get_token_params $get_token_url)
  
    local token=$(echo ${get_token_response} | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
  
    if [ -z "${token}" ]; then
        echo "Unable to fetch a server auth token."
    fi

    echo ${token}
}

function wait_until_server_service_is_available()
{
    local host=$1
    local health_check_url="https://$host:6443/arcgis/rest/info/healthcheck?f=json"

    echo "Checking if ArcGIS Server service for ($host) is up..."
    local response_code=$(curl -k -s -o /dev/null -w "%{http_code}" ${health_check_url})
    
    while [ ${response_code} != 200 ]; do
        echo "($response_code) - ArcGIS Server service for ($host) is not ready, waiting..."
        sleep ${POLLING_INTERVAL}
        response_code=$(curl -k -s -o /dev/null -w "%{http_code}" ${health_check_url})
    done

    echo "ArcGIS Server service for ($host) is available."
}

function wait_until_server_site_is_available()
{
    local host=$1
    local health_check_url="https://$host:6443/arcgis/rest/info/healthcheck?f=json"

    wait_until_server_service_is_available ${host}

    echo "Checking if ArcGIS Server site for ($host) is up..."
    local response=$(curl -k -s ${health_check_url})

    while [ "${response}" != "{\"success\":true}" ]; do
        echo ${response}
        echo "ArcGIS Server site for ($host) is not ready, waiting..."
        sleep ${POLLING_INTERVAL}
        response=$(curl -k -s ${health_check_url})
    done

    echo "ArcGIS Server site for ($host) is up."
}

update_server_system_properties()
{
    local host=$1
    local username=$2
    local password=$3
    local web_context_url=$4
    
    local referer="https://$host"
    local token=$(get_server_token $host $referer $username $password)
    echo "Token: $token"
    
    local server_properties="\"WebContextURL\":\"$web_context_url\""
    echo "Updating server system properties for ($host)..."
    echo "Properties: ${server_properties}"
    echo ""
    
    local update_properties_url="https://$host:6443/arcgis/admin/system/properties/update?token=$token&f=json"
    local update_properties_params="properties={$server_properties}"
    
    local update_properties_response=$(curl -s -k -X POST $update_properties_url -H 'Referer: '$referer -d $update_properties_params)
    
    echo "Response: $update_properties_response"
    echo ""
}

function is_server_federated()
{
    local host=$1
    local username=$2
    local password=$3

    local referer="https://$host"
    local token=$(get_server_token $host $referer $username $password)

    local security_config_url="https://$host:6443/arcgis/admin/security/config?token=$token&f=json"
    local security_config_response=$(curl -s -k -X GET $security_config_url -H 'Referer: '$referer)

    local auth_tier=$(echo ${security_config_response} | grep -o '"authenticationTier":"[^"]*' | grep -o '[^"]*$')

    if [ "$auth_tier" == "ARCGIS_PORTAL" ]; then
        echo true
    else
        echo false
    fi 
}