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
# NOTE: Setup for AV1 with Intel ARC; could be modified for
# Other Cards
# ============================================================

# ----------------- User Configuration Area -----------------
DOCKER_CONTAINER_NAME="380-128-N1"
TRANSCODING_DEVICE="/dev/dri/renderD128"
initial_delay=20  # Initial delay before starting the script (seconds)

# Duration of the initial Plex check (in seconds)
# This variable controls how long the script checks for Plex activity during the initial phase.
# The script will check once per second for the specified number of seconds. If Plex is detected,
# it will immediately turn off the Tdarr node and skip the remaining checks.
initial_check_duration=4  # Default is 4 seconds

plex_check_minutes=5  # Duration in minutes for Plex activity checks at the end
# ------------------------------------------------------------

# Initialize counters
t_restart=0
plex0_count=0

# Function: Log messages with timestamp
log_message() {
    echo "[$(date)] $1"
    sleep 1
}

# Function: Check if Plex is using the GPU without using grep
check_plex_usage() {
    lsof_output=$(lsof "$TRANSCODING_DEVICE")
    
    if echo "$lsof_output" | while read -r line; do
        if [[ "$line" == *"Plex"* ]]; then
            return 0
        fi
    done; then
        return 0
    else
        return 1
    fi
}

# Function: Turn off Tdarr node
turn_off_tdarr() {
    log_message "Turning off Tdarr node..."
    # Insert command to turn off Tdarr node
    sleep 1
}

# Function: Restart Docker container
restart_container() {
    log_message "Restarting Docker container $DOCKER_CONTAINER_NAME..."
    docker restart "$DOCKER_CONTAINER_NAME"
    t_restart=0  # Reset t_restart after restart
    sleep 1
}

# Initial delay with countdown and timestamp
log_message "Initial delay: Waiting $initial_delay seconds for Docker containers to load..."
for ((i = initial_delay; i > 0; i--)); do
    echo "[$(date)] Starting in $i seconds..."
    sleep 1
done

log_message "Initial delay complete, starting Tdarr check..."

# Simplified Initial Tdarr Turn-Off Check using the variable
for ((i = 1; i <= initial_check_duration; i++)); do
    if check_plex_usage; then
        log_message "Plex detected during initial check. Turning off Tdarr node."
        turn_off_tdarr
        break
    fi
    sleep 1  # Check every second
done

# Main loop
while true; do
    numbercheck=0
    numberplex=0

    while true; do
        numbercheck=$((numbercheck + 1))

        if check_plex_usage; then
            numberplex=$((numberplex + 1))
            log_message "Plex is currently transcoding (plex1 detected)."
            plex0_count=0  # Reset plex0_count if Plex is detected
            t_restart=0  # Reset t_restart when Plex is active

            if [ "$numberplex" -ge 4 ]; then
                log_message "Plex confirmed: Transcoding activity detected."
                
                if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
                    log_message "Stopping Docker container $DOCKER_CONTAINER_NAME..."
                    docker stop "$DOCKER_CONTAINER_NAME"
                else
                    log_message "Docker container $DOCKER_CONTAINER_NAME is not running."
                fi
                
                break
            fi
        else
            log_message "Plex is not currently transcoding (plex0 detected)."
            plex0_count=$((plex0_count + 1))
        fi
        
        if [ "$plex0_count" -ge 3 ]; then
            log_message "Plex not confirmed: No activity for 3 consecutive checks."
            
            if ! docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
                t_restart=$((t_restart + 1))
                log_message "t_restart count: $t_restart"
                
                remaining_increments=$((t_restart_threshold - t_restart))
                estimated_time=$((remaining_increments * 5))
                log_message "Estimated time to restart: $estimated_time seconds"
            else
                log_message "Docker container $DOCKER_CONTAINER_NAME is already running."
            fi

            sleep 5  # Wait before checking again

            if [ "$t_restart" -ge "$t_restart_threshold" ]; then
                restart_container
            fi
            break
        fi

        # Simplified Plex Check Towards the End
        total_checks=$((plex_check_minutes * 12))  # 12 checks per minute (every 5 seconds)
        if [ "$numbercheck" -ge "$total_checks" ]; then
            log_message "Plex check duration ($plex_check_minutes minutes) reached without Plex confirmation."
            sleep 5
            break
        fi
    done
done
