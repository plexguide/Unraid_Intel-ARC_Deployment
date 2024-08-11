#!/bin/bash

# Initial delay of 20 seconds to allow Docker containers to load
echo "Initial delay: Waiting 20 seconds for Docker containers to load..."
sleep 20

# Maximum number of checks before deciding Plex is not confirmed
MAX_CHECKS=10

# Initialize variables
t_restart=0
plex0_count=0
t_restart_threshold=60  # The threshold for t_restart

while true; do
    # Initialize variables at the start of each full run
    numbercheck=0
    numberplex=0
    TRANSCODING_DEVICE="/dev/dri/renderD128"

    while true; do
        # Increment numbercheck with each iteration
        numbercheck=$((numbercheck + 1))
        
        # Check if the device is being accessed by Plex
        check=$(lsof | grep "$TRANSCODING_DEVICE")
        
        if echo "$check" | grep -q "Plex"; then
            numberplex=$((numberplex + 1))
            echo "plex1"
            plex0_count=0  # Reset plex0_count if Plex is detected
            t_restart=0  # Reset t_restart when Plex transcoding is detected

            # Check if numberplex has reached 4 to confirm Plex usage
            if [ "$numberplex" -ge 4 ]; then
                echo "PLEX Confirmed"
                
                # Stop the Docker container if it's running
                if docker ps | grep -q "380-128-N1"; then
                    echo "Stopping Docker container 380-128-N1..."
                    docker stop 380-128-N1
                else
                    echo "Docker container 380-128-N1 is not running, skipping stop command."
                fi
                
                sleep 2  # Wait for 2 seconds before restarting the loop
                break
            fi

        else
            echo "plex0"
            plex0_count=$((plex0_count + 1))
        fi
        
        # Proceed only after plex0 has been echoed 3 times consecutively
        if [ "$plex0_count" -ge 3 ]; then
            echo "PLEX not confirmed"

            # Check if the Docker container 380-128-N1 is running before incrementing t_restart
            if ! docker ps | grep -q "380-128-N1"; then
                t_restart=$((t_restart + 1))  # Increment t_restart only if container is not running
                echo "t_restart count: $t_restart"

                # Calculate the estimated time in seconds to reach the threshold
                remaining_increments=$((t_restart_threshold - t_restart))
                estimated_time=$((remaining_increments * 5))  # 5 seconds per increment (as sleep 5 is used)
                echo "Estimated time to reach t_restart threshold: $estimated_time seconds"
            else
                echo "Docker container 380-128-N1 is already running, t_restart not incremented."
            fi
            
            # Sleep for 5 seconds for visual purposes
            sleep 5
            
            # If t_restart hits the threshold, restart the Docker container
            if [ "$t_restart" -ge "$t_restart_threshold" ]; then
                echo "Restarting Docker container 380-128-N1..."
                docker restart 380-128-N1
                t_restart=0  # Reset t_restart after restarting
            fi

            break
        fi

        # If numbercheck reaches MAX_CHECKS without plex0_count hitting 3, exit loop
        if [ "$numbercheck" -ge "$MAX_CHECKS" ]; then
            echo "MAX_CHECKS reached without PLEX not confirmed."
            sleep 5
            break
        fi

        # Optional: Add a sleep delay if you want to pause between iterations
        # sleep 1

    done

    # Restart the entire script after the 5-second delay
done
