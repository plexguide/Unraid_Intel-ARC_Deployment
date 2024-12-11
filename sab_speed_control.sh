#!/bin/bash

# ============================================================
# Script Name: SAB Speed Control 
# Author: Admin9705 
# ============================================================
# NOTE: Control DL speeds while others are watching PLEX
# ============================================================

# v1 - Initial Script | v2 - Added Night Speeds 

# Configuration
SABNZBD_API_KEY="60x7fega60f642d489ed89f08c4f8a80fake"
SABNZBD_URL="http://10.0.0.10:8081/sabnzbd/api"
SLOW_SPEED="65000000"       # DL Speed when Plex Transcoding
NORMAL_SPEED="85000000"     # DL Speed when Plex Not Transocding
NIGHT_SPEED="125000000"     # DL Speed when not using Internet and when Plex Not Transcoding (such as Night)

# 125000000 is 118.2 MB | 80000000 is 76.3 MB 

NIGHT_START="01"            # Start hour for nighttime speed (24-hour format) (01 is 0100 AM or 0100hrs)
NIGHT_END="07"              # End hour for nighttime speed (24-hour format)   (07 is 0700 AM or 0700hrs)

# Type Date in CMD Line to ENSURE that SERVER TIME matches/aligns as a test

CHECK_INTERVAL=10           # Seconds between checks
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf7c"
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
        # If Plex is playing/transcoding, use SLOW_SPEED
        set_sab_speed "${SLOW_SPEED}"
    else
        # If Plex is not playing/transcoding, check the current hour
        current_hour=$(date +%H)

        # Compare current hour to NIGHT_START and NIGHT_END
        if [ "${current_hour}" -ge "${NIGHT_START}" ] && [ "${current_hour}" -lt "${NIGHT_END}" ]; then
            # If current time is between NIGHT_START and NIGHT_END (exclusive of NIGHT_END), use NIGHT_SPEED
            set_sab_speed "${NIGHT_SPEED}"
        else
            # Otherwise, use NORMAL_SPEED
            set_sab_speed "${NORMAL_SPEED}"
        fi
    fi
    sleep "${CHECK_INTERVAL}"
done
