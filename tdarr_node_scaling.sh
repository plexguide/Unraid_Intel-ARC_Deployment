#!/bin/bash

###################################
# Configuration
###################################

# Where your Tdarr Node log is located
TDARR_NODE_LOG_PATH="/mnt/user/appdata/n1-1/logs/Tdarr_Node_Log.txt"

# ------------- T1 (Required) -------------
T1_TAUTULLI_API_KEY="ebdb8c80fc2b461ea182243dbc1b27a1"
T1_TAUTULLI_URL="http://10.0.0.10:8181/api/v2"

####################################### IMPORTANT NOTE #######################################
# Additional Tautulli configurations are only needed if you run multiple Plex servers
# on the same GPU (e.g., a primary and a backup Plex instance). This lets the script
# track transcodes across all your servers sharing that single GPU.
#
# In most cases (99% of setups), you only have one Plex server (per gpu), so you can ignore
# any extra Tautulli entries.

# ------------- T2 (Optional) -------------
T2_TAUTULLI_API_KEY=""
T2_TAUTULLI_URL=""

# ------------- T3 (Optional) -------------
T3_TAUTULLI_API_KEY=""
T3_TAUTULLI_URL=""

# ------------- T4 (Optional) -------------
T4_TAUTULLI_API_KEY=""
T4_TAUTULLI_URL=""
###############################################################################################

# ----------- Tdarr Settings -------------
TDARR_ALTER_WORKERS=true       # If true, we adjust GPU workers; otherwise we kill container on threshold
TDARR_DEFAULT_LIMIT=5          # Default GPU workers when watchers=0
TDARR_API_URL="http://10.0.0.10:8265"   # WITHOUT /api/v2
CONTAINER_NAME="N1"            # Name of your Tdarr Node Docker container

# ------------ IF >>> TDARR_ALTER_WORKERS=true 
# We only start reducing workers when watchers >= OFFSET_THRESHOLD.
OFFSET_THRESHOLD=2      # For Tdarr Scaling, number of transcodes reached to start reducing GPU Workers by 1 for each >= OFFSET_THRESHOLD

# ------------ IF >>> TDARR_ALTER_WORKERS=false
TRANSCODE_THRESHOLD=4   # For Tdarr Killer, number of transcodes reached to kill the tdarr node (when TDARR_ALTER_WORKERS=false)

# ----------- Other -------------
WAIT_SECONDS=10                # Sleep after adjustments
BASIC_CHECK=3                  # Poll interval (seconds) when idle

###################################
# End of configuration
###################################

# Simple logging function with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# ------------------------------------------------------------
# Function: find_latest_node_id
# ------------------------------------------------------------
find_latest_node_id() {
    if [ -f "$TDARR_NODE_LOG_PATH" ]; then
        local found
        found=$(grep -oP '"nodeID":\s*"\K[^"]+' "$TDARR_NODE_LOG_PATH" | tail -n1)
        echo "$found"
    else
        echo ""
    fi
}

# Initialize global variable
TDARR_NODE_ID=""

# ------------------------------------------------------------
# Function: ensure_node_id_loaded
# ------------------------------------------------------------
ensure_node_id_loaded() {
    if [ -n "$TDARR_NODE_ID" ]; then
        return 0
    fi

    log_message "Attempting to retrieve nodeID from $TDARR_NODE_LOG_PATH"
    local found
    found=$(find_latest_node_id)

    if [ -z "$found" ]; then
        log_message "ERROR: Could not find any nodeID in $TDARR_NODE_LOG_PATH."
        return 1
    fi

    TDARR_NODE_ID="$found"
    log_message "Found nodeID: $TDARR_NODE_ID"
    return 0
}

# ------------------------------------------------------------
# Function: refresh_node_id_if_changed
# ------------------------------------------------------------
refresh_node_id_if_changed() {
    local latest
    latest=$(find_latest_node_id)
    if [ -z "$latest" ]; then
        log_message "WARNING: Could not find any 'nodeID' lines in the log to refresh."
        return
    fi

    if [ "$latest" != "$TDARR_NODE_ID" ]; then
        log_message "NOTICE: nodeID changed from [$TDARR_NODE_ID] -> [$latest]. Updating."
        TDARR_NODE_ID="$latest"
    else
        log_message "NOTICE: nodeID is still the same [$TDARR_NODE_ID]."
    fi
}

# ------------------------------------------------------------
# Function: check_single_tautulli_connection
# ------------------------------------------------------------
check_single_tautulli_connection() {
    local api_key="$1"
    local url="$2"
    if [ -z "$api_key" ] || [ -z "$url" ]; then
        return 2
    fi

    log_message "Checking Tautulli at: $url"
    local response
    response=$(curl -s "${url}?apikey=${api_key}&cmd=get_activity")

    if echo "$response" | jq . >/dev/null 2>&1; then
        log_message "Tautulli OK: $url"
        return 0
    else
        log_message "WARNING: Could not connect or invalid JSON: $url"
        return 1
    fi
}

# ------------------------------------------------------------
# Function: check_tautulli_connections_on_startup
# ------------------------------------------------------------
check_tautulli_connections_on_startup() {
    # T1 must work
    check_single_tautulli_connection "$T1_TAUTULLI_API_KEY" "$T1_TAUTULLI_URL"
    if [ $? -ne 0 ]; then
        log_message "ERROR: T1 not reachable. Exiting."
        exit 1
    fi

    # T2..T4 are optional
    check_single_tautulli_connection "$T2_TAUTULLI_API_KEY" "$T2_TAUTULLI_URL" || true
    check_single_tautulli_connection "$T3_TAUTULLI_API_KEY" "$T3_TAUTULLI_URL" || true
    check_single_tautulli_connection "$T4_TAUTULLI_API_KEY" "$T4_TAUTULLI_URL" || true
}

# ------------------------------------------------------------
# Function: fetch_transcode_counts_from_tautulli
# ------------------------------------------------------------
fetch_transcode_counts_from_tautulli() {
    local api_key="$1"
    local url="$2"

    if [ -z "$api_key" ] || [ -z "$url" ]; then
        echo "0 0"
        return
    fi

    local resp
    resp=$(curl -s "${url}?apikey=${api_key}&cmd=get_activity")
    if ! echo "$resp" | jq . >/dev/null 2>&1; then
        echo "0 0"
        return
    fi

    local local_cnt remote_cnt
    # Only count sessions that are transcoding video, not just audio
    local_cnt=$(echo "$resp" | jq '[.response.data.sessions[]?
       | select(.transcode_decision == "transcode" and .video_decision == "transcode" and (.ip_address | startswith("10.0.0.")))] | length')
    remote_cnt=$(echo "$resp" | jq '[.response.data.sessions[]?
       | select(.transcode_decision == "transcode" and .video_decision == "transcode" and (.ip_address | startswith("10.0.0.") | not))] | length')

    echo "$local_cnt $remote_cnt"
}

# ------------------------------------------------------------
# Global watchers total
# ------------------------------------------------------------
total_count=0

# ------------------------------------------------------------
# Function: is_plex_transcoding_over_threshold
# ------------------------------------------------------------
is_plex_transcoding_over_threshold() {
    log_message "Checking Plex transcodes..."

    local total_local=0
    local total_remote=0

    # T1
    read t1_local t1_remote < <(fetch_transcode_counts_from_tautulli "$T1_TAUTULLI_API_KEY" "$T1_TAUTULLI_URL")
    total_local=$(( total_local + t1_local ))
    total_remote=$(( total_remote + t1_remote ))

    # T2
    read t2_local t2_remote < <(fetch_transcode_counts_from_tautulli "$T2_TAUTULLI_API_KEY" "$T2_TAUTULLI_URL")
    total_local=$(( total_local + t2_local ))
    total_remote=$(( total_remote + t2_remote ))

    # T3
    read t3_local t3_remote < <(fetch_transcode_counts_from_tautulli "$T3_TAUTULLI_API_KEY" "$T3_TAUTULLI_URL")
    total_local=$(( total_local + t3_local ))
    total_remote=$(( total_remote + t3_remote ))

    # T4
    read t4_local t4_remote < <(fetch_transcode_counts_from_tautulli "$T4_TAUTULLI_API_KEY" "$T4_TAUTULLI_URL")
    total_local=$(( total_local + t4_local ))
    total_remote=$(( total_remote + t4_remote ))

    total_count=$(( total_local + total_remote ))

    log_message "Found $total_local local & $total_remote remote => total=$total_count, threshold=$TRANSCODE_THRESHOLD"

    # Return 0 if watchers >= threshold
    if [ "$total_count" -ge "$TRANSCODE_THRESHOLD" ]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------
# Function: is_container_running
# ------------------------------------------------------------
is_container_running() {
    local s
    s=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)
    [ "$s" = "true" ]
}

# ------------------------------------------------------------
# Function: adjust_tdarr_workers
# 
# We only start subtracting from TDARR_DEFAULT_LIMIT once watchers >= OFFSET_THRESHOLD.
# Example with OFFSET_THRESHOLD=3:
#   watchers=2 => no reduce
#   watchers=3 => reduce by 1
#   watchers=4 => reduce by 2, etc.
# ------------------------------------------------------------
adjust_tdarr_workers() {
    ensure_node_id_loaded || return

    local watchers="$1"

    # 1) Calculate how many watchers are above the offset
    #    If OFFSET_THRESHOLD=0, use watchers directly
    #    If OFFSET_THRESHOLD>0 and watchers < OFFSET_THRESHOLD => watchersOverOffset=0
    #    If OFFSET_THRESHOLD>0 and watchers=3 => watchersOverOffset=1 => reduce by 1
    #    If OFFSET_THRESHOLD>0 and watchers=4 => watchersOverOffset=2 => reduce by 2, etc.
    local watchersOverOffset
    if [ "$OFFSET_THRESHOLD" -eq 0 ]; then
        # When offset is 0, reduce by exactly the watcher count
        watchersOverOffset=$watchers
    else
        # When offset >0, start reducing only after reaching threshold
        watchersOverOffset=$(( watchers - OFFSET_THRESHOLD + 1 ))
        if [ "$watchersOverOffset" -lt 0 ]; then
            watchersOverOffset=0
        fi
    fi

    # 2) Desired = TDARR_DEFAULT_LIMIT - watchersOverOffset
    local desired=$(( TDARR_DEFAULT_LIMIT - watchersOverOffset ))
    if [ "$desired" -lt 0 ]; then
        desired=0
    fi

    log_message "watchers=$watchers => watchersOverOffset=$watchersOverOffset => desiredWorkers=$desired"

    # poll-worker-limits
    local poll_resp
    poll_resp=$(curl -s -X POST "${TDARR_API_URL}/api/v2/poll-worker-limits" \
        -H "Content-Type: application/json" \
        -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'"}}')

    local current
    current=$(echo "$poll_resp" | jq '.workerLimits.transcodegpu' 2>/dev/null)
    if [ -z "$current" ] || [ "$current" = "null" ]; then
        log_message "ERROR: Could not retrieve current GPU worker limit for nodeID='$TDARR_NODE_ID'. Will re-check log for a new ID."
        refresh_node_id_if_changed
        return
    fi

    log_message "Current GPU worker limit: $current"

    local diff=$(( desired - current ))
    if [ "$diff" -eq 0 ]; then
        log_message "Already at the desired GPU worker limit ($desired)."
        return
    fi

    local step
    if [ "$diff" -gt 0 ]; then
        step="increase"
        log_message "Need to increase by $diff"
    else
        step="decrease"
        diff=$(( -diff ))
        log_message "Need to decrease by $diff"
    fi

    local i=0
    while [ $i -lt $diff ]; do
        curl -s -X POST "${TDARR_API_URL}/api/v2/alter-worker-limit" \
            -H "Content-Type: application/json" \
            -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'","process":"'"$step"'","workerType":"transcodegpu"}}' \
            >/dev/null 2>&1
        i=$(( i + 1 ))
        sleep 1
    done

    log_message "GPU worker limit adjustment complete."
}

# ------------------------------------------------------------
# Main Script
# ------------------------------------------------------------
ensure_node_id_loaded
check_tautulli_connections_on_startup

# Main loop with protection against duplicate operations
last_operation=""
last_gpu_limit=0
consecutive_duplicates=0

# Set initial GPU workers on startup
if [ "$TDARR_ALTER_WORKERS" = "true" ]; then
    log_message "Setting initial GPU workers to default limit: $TDARR_DEFAULT_LIMIT on startup"
    
    # Ensure we have nodeID before trying to set workers
    ensure_node_id_loaded || {
        log_message "ERROR: Could not get nodeID, can't set initial GPU workers"
        sleep 5  # Wait a bit and continue, will try again in the main loop
    }
    
    if [ -n "$TDARR_NODE_ID" ]; then
        # Get current limit
        current_limit=$(curl -s -X POST "${TDARR_API_URL}/api/v2/poll-worker-limits" \
            -H "Content-Type: application/json" \
            -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'"}}' | \
            jq '.workerLimits.transcodegpu' 2>/dev/null)
            
        if [ -n "$current_limit" ] && [ "$current_limit" != "null" ]; then
            # Calculate how many workers to add/remove
            diff=$(( TDARR_DEFAULT_LIMIT - current_limit ))
            
            if [ "$diff" -ne 0 ]; then
                step=""
                count=0
                
                if [ "$diff" -gt 0 ]; then
                    step="increase"
                    count=$diff
                    log_message "Need to increase by $diff to reach default limit"
                else
                    step="decrease"
                    count=$(( -diff ))
                    log_message "Need to decrease by $(( -diff )) to reach default limit"
                fi
                
                i=0
                while [ $i -lt $count ]; do
                    curl -s -X POST "${TDARR_API_URL}/api/v2/alter-worker-limit" \
                        -H "Content-Type: application/json" \
                        -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'","process":"'"$step"'","workerType":"transcodegpu"}}' \
                        >/dev/null 2>&1
                    i=$(( i + 1 ))
                    sleep 1
                done
                
                log_message "Initial GPU worker limit set to $TDARR_DEFAULT_LIMIT"
            else
                log_message "GPU workers already at desired default limit: $current_limit"
            fi
        else
            log_message "ERROR: Could not get current GPU worker limit"
        fi
    fi
fi

while true; do
    if is_plex_transcoding_over_threshold; then
        # watchers >= threshold
        if [ "$TDARR_ALTER_WORKERS" = "true" ]; then
            # Check if we're doing the same operation repeatedly
            operation="reduce_workers_$total_count"
            
            # Get current limit to check if it changed
            current_limit=$(curl -s -X POST "${TDARR_API_URL}/api/v2/poll-worker-limits" \
                -H "Content-Type: application/json" \
                -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'"}}' | \
                jq '.workerLimits.transcodegpu' 2>/dev/null)
            
            if [ "$operation" = "$last_operation" ] && [ "$current_limit" = "$last_gpu_limit" ]; then
                consecutive_duplicates=$((consecutive_duplicates + 1))
                if [ $consecutive_duplicates -gt 2 ]; then
                    log_message "Skipping duplicate worker adjustment (done $consecutive_duplicates times already)"
                    sleep "$WAIT_SECONDS"
                    continue
                fi
            else
                consecutive_duplicates=0
            fi
            
            last_operation="$operation"
            last_gpu_limit="$current_limit"
            
            log_message "Threshold exceeded. Reducing GPU workers."
            adjust_tdarr_workers "$total_count"
            sleep "$WAIT_SECONDS"
        else
            # kill container
            operation="kill_container"
            
            if [ "$operation" = "$last_operation" ]; then
                consecutive_duplicates=$((consecutive_duplicates + 1))
                if [ $consecutive_duplicates -gt 2 ]; then
                    log_message "Skipping duplicate container management (done $consecutive_duplicates times already)"
                    sleep "$WAIT_SECONDS"
                    continue
                fi
            else
                consecutive_duplicates=0
            fi
            
            last_operation="$operation"
            
            if is_container_running; then
                log_message "Threshold exceeded: Killing $CONTAINER_NAME"
                docker kill "$CONTAINER_NAME"
            else
                log_message "$CONTAINER_NAME is already stopped."
            fi
            sleep "$WAIT_SECONDS"
        fi
    else
        # watchers < threshold
        if [ "$TDARR_ALTER_WORKERS" = "true" ]; then
            # Check if we're doing the same operation repeatedly
            operation="adjust_workers_$total_count"
            
            # Get current limit to check if it changed
            current_limit=$(curl -s -X POST "${TDARR_API_URL}/api/v2/poll-worker-limits" \
                -H "Content-Type: application/json" \
                -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'"}}' | \
                jq '.workerLimits.transcodegpu' 2>/dev/null)
            
            if [ "$operation" = "$last_operation" ] && [ "$current_limit" = "$last_gpu_limit" ]; then
                consecutive_duplicates=$((consecutive_duplicates + 1))
                if [ $consecutive_duplicates -gt 2 ]; then
                    log_message "Skipping duplicate worker adjustment (done $consecutive_duplicates times already)"
                    sleep "$BASIC_CHECK"
                    continue
                fi
            else
                consecutive_duplicates=0
            fi
            
            last_operation="$operation"
            last_gpu_limit="$current_limit"
            
            adjust_tdarr_workers "$total_count"
        fi

        # Start container if needed
        operation="start_container"
        
        if [ "$operation" = "$last_operation" ] && is_container_running; then
            consecutive_duplicates=$((consecutive_duplicates + 1))
            if [ $consecutive_duplicates -gt 2 ]; then
                log_message "Skipping duplicate container check (done $consecutive_duplicates times already)"
                sleep "$BASIC_CHECK"
                continue
            fi
        else
            consecutive_duplicates=0
        fi
        
        last_operation="$operation"

        if ! is_container_running; then
            log_message "Below threshold -> Starting container $CONTAINER_NAME."
            docker start "$CONTAINER_NAME"
        else
            log_message "Container $CONTAINER_NAME is already running."
        fi

        sleep "$BASIC_CHECK"
    fi
done
