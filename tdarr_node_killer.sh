#!/bin/bash

# Configuration
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf7c"   # Tautulli API Key
TAUTULLI_URL="http://10.0.0.10:8181/api/v2"           # Tautulli URL
WAIT_SECONDS=180                                      # Wait time (in seconds) after killing the tdarr node
BASIC_CHECK=3                                         # Basic check interval when Plex is idle
CONTAINER_NAME="N4"                                   # Exact name of your tdarr node container

# The total number of transcodes (local + remote) required to trigger Tdarr shutdown
TRANSCODE_THRESHOLD=3

# Function to check if Plex is transcoding via Tautulli
# Returns 0 (true) if total transcodes >= threshold, else returns 1 (false).
is_plex_transcoding_over_threshold() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Plex activity via Tautulli API"
    response=$(curl -s "${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity")

    # Count local and remote transcoding sessions
    local_count=$(echo "$response" | jq '[.response.data.sessions[]? | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.")))] | length')
    remote_count=$(echo "$response" | jq '[.response.data.sessions[]? | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.") | not))] | length')
    total_count=$(( local_count + remote_count ))
    
    # Log counts
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Detected ${local_count} local and ${remote_count} remote transcoding session(s)."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Total transcodes: ${total_count}, Threshold: ${TRANSCODE_THRESHOLD}"

    # If total_count >= threshold, signal that we should kill Tdarr
    if [ "$total_count" -ge "$TRANSCODE_THRESHOLD" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Total transcodes >= threshold (${TRANSCODE_THRESHOLD})."
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Total transcodes below threshold. No kill."
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
    # Check if total transcodes >= threshold
    if is_plex_transcoding_over_threshold; then
        # Ensure the container is not running
        if is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Killing Docker container ${CONTAINER_NAME} due to Plex transcode threshold."
            docker kill "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already stopped."
        fi

        # Wait before checking again
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sleeping for ${WAIT_SECONDS} seconds..."
        sleep "${WAIT_SECONDS}"
    else
        # If below threshold, ensure the container is running
        if ! is_container_running; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting Docker container ${CONTAINER_NAME} since transcodes are below threshold."
            docker start "${CONTAINER_NAME}"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${CONTAINER_NAME} is already running, no action needed."
        fi

        # Sleep before next check
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sleeping for ${BASIC_CHECK} seconds..."
        sleep "${BASIC_CHECK}"
    fi
done
