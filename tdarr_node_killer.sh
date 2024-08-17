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
# Modify the following variables based on your environment

# Docker container name to monitor and restart
DOCKER_CONTAINER_NAME="380-128-N1"

# Path to the GPU device being used by Plex for transcoding
TRANSCODING_DEVICE="/dev/dri/renderD128"

# Initial delay to allow Docker containers to load before starting
initial_delay=60  # Default is 60 seconds, adjust if needed
# ------------------------------------------------------------

# Maximum number of checks before deciding Plex is not confirmed
MAX_CHECKS=10

# Threshold for t_restart before the Docker container is restarted
t_restart_threshold=60  # Default is 60, adjust if needed

# Initialize variables
t_restart=0
plex0_count=0

# Initial delay before starting the script's main loop
echo "[$(date)] Initial delay: Waiting $initial_delay seconds for Docker containers to load..."
sleep $initial_delay

while true; do
    # Initialize variables at the start of each full run
    numbercheck=0
    numberplex=0

    while true; do
        # Increment numbercheck with each iteration
        numbercheck=$((numbercheck + 1))
        
        # Check if the device is being accessed by Plex
        check=$(lsof | grep "$TRANSCODING_DEVICE")
        
        if echo "$check" | grep -q "Plex"; then
            numberplex=$((numberplex + 1))
            echo "[$(date)] plex1 detected: Plex is currently transcoding."
            plex0_count=0  # Reset plex0_count if Plex is detected
            t_restart=0  # Reset t_restart when Plex transcoding is detected

            # Check if numberplex has reached 4 to confirm Plex usage
            if [ "$numberplex" -ge 4 ]; then
                echo "[$(date)] PLEX Confirmed: Plex has reached the required number of transcoding events."
                
                # Stop the Docker container if it's running
                if docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
                    echo "[$(date)] Stopping Docker container $DOCKER_CONTAINER_NAME..."
                    docker stop "$DOCKER_CONTAINER_NAME"
                else
                    echo "[$(date)] Docker container $DOCKER_CONTAINER_NAME is not running. Skipping stop command."
                fi
                
                sleep 2  # Wait for 2 seconds before restarting the loop
                break
            fi

        else
            echo "[$(date)] plex0 detected: Plex is not currently transcoding."
            plex0_count=$((plex0_count + 1))
        fi
        
        # Proceed only after plex0 has been echoed 3 times consecutively
        if [ "$plex0_count" -ge 3 ]; then
            echo "[$(date)] PLEX not confirmed: Plex has not been detected for 3 consecutive checks."

            # Check if the Docker container is running before incrementing t_restart
            if ! docker ps | grep -q "$DOCKER_CONTAINER_NAME"; then
                t_restart=$((t_restart + 1))  # Increment t_restart only if container is not running
                echo "[$(date)] t_restart count: $t_restart"

                # Calculate and echo the estimated time to reach the restart threshold
                remaining_increments=$((t_restart_threshold - t_restart))
                estimated_time=$((remaining_increments * 5))  # 5 seconds per increment (as sleep 5 is used)
                echo "[$(date)] Estimated time to reach t_restart threshold: $estimated_time seconds"
            else
                echo "[$(date)] Docker container $DOCKER_CONTAINER_NAME is already running. t_restart not incremented."
            fi
            
            # Sleep for 5 seconds for visual purposes
            sleep 5
            
            # If t_restart hits the threshold, restart the Docker container
            if [ "$t_restart" -ge "$t_restart_threshold" ]; then
                echo "[$(date)] Restarting Docker container $DOCKER_CONTAINER_NAME..."
                docker restart "$DOCKER_CONTAINER_NAME"
                t_restart=0  # Reset t_restart after restarting
            fi

            break
        fi

        # If numbercheck reaches MAX_CHECKS without plex0_count hitting 3, exit loop
        if [ "$numbercheck" -ge "$MAX_CHECKS" ]; then
            echo "[$(date)] MAX_CHECKS reached without Plex confirmation. Exiting loop."
            sleep 5
            break
        fi

        # Optional: Add a sleep delay if you want to pause between iterations
        # sleep 1

    done

    # Restart the entire script after the 5-second delay
done
