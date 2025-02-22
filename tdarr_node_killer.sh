#!/bin/bash

# Configuration
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf7c"   # Tautulli API Key
TAUTULLI_URL="http://10.0.0.10:8181/api/v2"            # Tautulli URL
WAIT_SECONDS=180                                      # Wait time (in seconds) after killing the tdarr node before checking again
BASIC_CHECK=3                                         # Basic check interval when Plex is idle
CONTAINER_NAME="N4"                                   # The exact name of your tdarr node container
# Option: set to "yes" to disable tdarr only when a remote transcode is detected.
# When set to "yes", if a remote transcode is active (even with local transcodes), tdarr is disabled.
# Set to "no" to disable tdarr whenever any transcoding session (local or remote) is detected.
DISABLE_TDARR_FOR_LOCAL_ONLY="yes"

# Function to sleep while logging status every 5 seconds
sleep_with_status() {
    local duration=$1
    local interval=5
    local elapsed=0

    while [ $elapsed -lt $duration ]; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting... ($elapsed/${duration}s elapsed)"
        sleep $interval
        elapsed=$(( elapsed + interval ))
    done
}

# Function to check if Plex is transcoding via Tautulli.
is_plex_transcoding() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Plex activity via Tautulli API"
    response=$(curl -s "${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity")

    # Count local and remote transcoding sessions.
    # Assumes that each session includes an "ip_address" field.
    local_count=$(echo "$response" | jq '[.response.data.sessions[]? | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.")))] | length')
    remote_count=$(echo "$response" | jq '[.response.data.sessions[]? | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.") | not))] | length')
    total_count=$(( local_count + remote_count ))
    
    # Log counts.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected ${local_count} local and ${remote_count} remote transcoding session(s)."
    
    if [ "$DISABLE_TDARR_FOR_LOCAL_ONLY" = "yes" ]; then
        # Only remote transcoding triggers tdarr disable, even if local transcodes exist.
        if [ "$remote_count" -gt 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Remote transcoding detected."
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - No remote transcoding detected (only local transcoding active or none at all)."
            return 1
        fi
    else
        # Any transcoding session triggers tdarr disable.
        if [ "$total_count" -gt 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Plex is transcoding ${total_count} session(s)."
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - No Plex transcoding detected."
            return 1
        fi
    fi
}

# Function to check if the container is running.
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
        # If transcoding (by the chosen criteria) is detected, ensure the container is not running.
        if is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Killing Docker container ${CONTAINER_NAME} due to Plex transcoding."
            docker kill "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already stopped."
        fi

        # Wait before checking again with status updates.
        sleep_with_status "${WAIT_SECONDS}"
    else
        # When no triggering transcode is detected, if the container is stopped then start it.
        if ! is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Docker container ${CONTAINER_NAME} since Plex is not transcoding."
            docker start "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already running, no action needed."
        fi

        # Wait before next check with status updates.
        sleep_with_status "${BASIC_CHECK}"
    fi
done
