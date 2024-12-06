#!/bin/bash

# Configuration
SABNZBD_API_KEY="60a7feba60f642d489ed89f08c4f8a88"
SABNZBD_URL="http://10.0.0.10:8081/sabnzbd/api"
SLOW_SPEED="85000000"   # 80000000 is 76.3 MB
NORMAL_SPEED="105000000" # 125000000 is 118.2 MB
CHECK_INTERVAL=10     # Seconds between checks
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf7d"
TAUTULLI_URL="http://10.0.0.10:8181/api/v2"

# Function to set SABnzbd speed limit
set_sab_speed() {
    local speed=$1
    local full_url="${SABNZBD_URL}?mode=config&name=speedlimit&value=${speed}&apikey=${SABNZBD_API_KEY}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sending request to set SABnzbd speed to ${speed} KB/s"
    response=$(curl -s "${full_url}")

    if [[ -z $response ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No response received from SABnzbd API."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SABnzbd API response: ${response}"
    fi
}

# Function to check if Plex is playing a file via Tautulli API
is_plex_playing() {
    local full_url="${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Plex activity via Tautulli API"

    response=$(curl -s "${full_url}" | jq -r '.response.data.sessions | length')
    
    if [[ "$response" -gt 0 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Plex is currently playing $response file(s)"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - No Plex playback detected"
        return 1
    fi
}

# Monitoring loop
while true; do
    if is_plex_playing; then
        set_sab_speed "${SLOW_SPEED}"
    else
        set_sab_speed "${NORMAL_SPEED}"
    fi
    sleep "${CHECK_INTERVAL}"
done
