#!/bin/bash

POLLING_INTERVAL=5

function wait_forever()
{
    while true; do
        sleep $POLLING_INTERVAL
    done
}

function apply_volume_mapping()
{
    local volume_directory=$1
    local source_directory=$2
    
    # Assuming its either a directory or a file
    local content=$3

    # Create the directory in the volume if it does not exist.
    if [ ! -d "$volume_directory" ]; then
        mkdir -p ${volume_directory}
    fi

    # Move the file/folder contents from the container to the volume, if not
    # present in the volume.
    if [ ! -d "$volume_directory/$content" ]; then
        mv ${source_directory}/${content} ${volume_directory}
    fi

    # Delete the content in the container if present.  This can happen if a container
    # is destroyed then re-created.  
    if [ -d "${source_directory}/$content" ]; then
        rm -rf ${source_directory}/${content}
    fi

    # Symlink the contents from the volume to the correct place in the file system
    # within the container.
    ln -s ${volume_directory}/${content} ${source_directory}/${content}
}