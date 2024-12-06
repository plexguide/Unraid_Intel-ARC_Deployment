#!/bin/bash

# ============================================================
# Script Name: Plex Transcoding & Docker Management Script
# Author: Admin9705 & Reddit
# Description:
# This script monitors Plex transcoding activity on a specified
# GPU device. If Plex is detected using the GPU, it resets a
# restart counter. If Plex does not use the GPU for a defined
# number of checks, it increments a counter. Once the counter
# reaches a threshold, the script restarts a specified Docker
# container. The script is designed to run indefinitely and
# includes logging for monitoring and troubleshooting.
# ============================================================
# NOTE: Requires Tautulli
# ============================================================
#!/bin/bash

# Configuration
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf6a" #your api key
TAUTULLI_URL="http://10.0.0.10:8181/api/v2" #your tautulli url
WAIT_SECONDS=180 #wait time for when script killed tdarr node to bring up tdarr node again; do not have short to ensure that plex transcodning has occured in awhile
BASIC_CHECK=3 #wait time to check when plex is not transcoding
CONTAINER_NAME="N1" #the exact name of your tdarr node that you want killed

# Function to check if Plex is transcoding via Tautulli
is_plex_transcoding() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Plex activity via Tautulli API"
    response=$(curl -s "${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity")
    # Count how many sessions are transcoding
    transcoding_count=$(echo "$response" | jq '[.response.data.sessions[]?.transcode_decision == "transcode"] | map(select(. == true)) | length')

    if [ "$transcoding_count" -gt 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Plex is currently transcoding $transcoding_count session(s)."
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No Plex transcoding detected."
        return 1
    fi
}

# Function to check if the container is running
is_container_running() {
    state=$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null)
    if [ "$state" = "true" ]; then
        return 0
    else
        return 1
    fi
}

while true; do
    if is_plex_transcoding; then
        # Plex is transcoding, ensure container is not running
        if is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Killing Docker container ${CONTAINER_NAME} due to Plex transcoding."
            docker kill "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already stopped."
        fi

        # Wait before checking again
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sleeping for ${WAIT_SECONDS} seconds..."
        sleep "${WAIT_SECONDS}"
    else
        # Plex is not transcoding
        # Check if container is running, if not, start it
        if ! is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Docker container ${CONTAINER_NAME} since Plex is not transcoding."
            docker start "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already running, no action needed."
        fi

        # Sleep before next check
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sleeping for ${BASIC_CHECK} seconds..."
        sleep "${BASIC_CHECK}"
    fi
done
