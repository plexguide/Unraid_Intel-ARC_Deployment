#!/bin/bash

###################################
# Configuration
###################################

# Where your Tdarr Node log is located
TDARR_NODE_LOG_PATH="/mnt/user/appdata/n1-1/logs/Tdarr_Node_Log.txt"

# ------------- T1 (Required) -------------
T1_TAUTULLI_API_KEY="ebdb8c80fc2b461ea182243dbc1b27a1"
T1_TAUTULLI_URL="http://10.0.0.10:8181/api/v2"

######################################## IMPORTANT NOTE ########################################
# The additional Tautulli's are needed if you are running multiple PLEX SERVERS on the SAME GPU.
# This is useful if you only have one GPU, but need to run a PLEX Primary and Backup Servers.
# If you do not understand, ignore it. Typically 99% of people will not utilize this.

# ------------- T2 (Optional) -------------
T2_TAUTULLI_API_KEY=""
T2_TAUTULLI_URL=""

# ------------- T3 (Optional) -------------
T3_TAUTULLI_API_KEY=""
T3_TAUTULLI_URL=""

# ------------- T4 (Optional) -------------
T4_TAUTULLI_API_KEY=""
T4_TAUTULLI_URL=""

# ----------- Tdarr Settings -------------
TDARR_ALTER_WORKERS=true       # If true, we adjust GPU workers; otherwise we kill container on threshold
TDARR_DEFAULT_LIMIT=5          # Default GPU workers when watchers=0
TDARR_API_URL="http://10.0.0.10:8265"   # Without /api/v2
CONTAINER_NAME="N1"            # Name of your Tdarr Node Docker container

# ----------- Other -------------
WAIT_SECONDS=10                # Sleep after adjustments
BASIC_CHECK=3                  # Poll interval (seconds) when idle
TRANSCODE_THRESHOLD=4          # # watchers that triggers kill or reduce workers

###################################
# End of configuration
###################################


# ------------------------------------------------------------
# Function: find_latest_node_id
# Grabs the most recent "nodeID": "xxxx" from the Node log.
# If not found, returns empty string.
# ------------------------------------------------------------
find_latest_node_id() {
    if [ -f "$TDARR_NODE_LOG_PATH" ]; then
        # use grep to find lines like `"nodeID": "26Rf3QImB",`
        # tail -n1 picks the latest occurrence
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
# Checks if we have TDARR_NODE_ID already set. If not, tries to find it from the log.
# If the log doesn't have it, we fail.
# ------------------------------------------------------------
ensure_node_id_loaded() {
    if [ -n "$TDARR_NODE_ID" ]; then
        return 0  # We already have a Node ID
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempting to retrieve nodeID from $TDARR_NODE_LOG_PATH"
    local found
    found=$(find_latest_node_id)

    if [ -z "$found" ]; then
        echo "ERROR: Could not find any nodeID in $TDARR_NODE_LOG_PATH."
        echo "Script cannot proceed until the Node logs show a 'nodeID' line."
        return 1
    fi

    TDARR_NODE_ID="$found"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Found nodeID: $TDARR_NODE_ID"
    return 0
}

# ------------------------------------------------------------
# Function: refresh_node_id_if_changed
# If the node restarts and the ID changes, pick up the new one automatically.
# We call this if we see "Could not retrieve current GPU worker limit," etc.
# ------------------------------------------------------------
refresh_node_id_if_changed() {
    local latest
    latest=$(find_latest_node_id)
    if [ -z "$latest" ]; then
        echo "WARNING: Could not find any 'nodeID' lines in the log to refresh."
        return
    fi

    if [ "$latest" != "$TDARR_NODE_ID" ]; then
        echo "NOTICE: nodeID changed from [$TDARR_NODE_ID] -> [$latest]. Updating."
        TDARR_NODE_ID="$latest"
    else
        echo "NOTICE: nodeID is still the same [$TDARR_NODE_ID]."
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

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Tautulli at: $url"
    local response
    response=$(curl -s "${url}?apikey=${api_key}&cmd=get_activity")

    if echo "$response" | jq . >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Tautulli OK: $url"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Could not connect or invalid JSON: $url"
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
        echo "ERROR: T1 not reachable. Exiting."
        exit 1
    fi

    # T2..T4 are optional
    check_single_tautulli_connection "$T2_TAUTULLI_API_KEY" "$T2_TAUTULLI_URL" || true
    check_single_tautulli_connection "$T3_TAUTULLI_API_KEY" "$T3_TAUTULLI_URL" || true
    check_single_tautulli_connection "$T4_TAUTULLI_API_KEY" "$T4_TAUTULLI_URL" || true
}

# ------------------------------------------------------------
# Function: fetch_transcode_counts_from_tautulli
# Returns "local_cnt remote_cnt" or "0 0" on error
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
    local_cnt=$(echo "$resp" | jq '[.response.data.sessions[]?
       | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.")))] | length')
    remote_cnt=$(echo "$resp" | jq '[.response.data.sessions[]?
       | select(.transcode_decision == "transcode" and (.ip_address | startswith("10.0.0.") | not))] | length')

    echo "$local_cnt $remote_cnt"
}

# ------------------------------------------------------------
# Global watchers total
# ------------------------------------------------------------
total_count=0

# ------------------------------------------------------------
# Function: is_plex_transcoding_over_threshold
# sets total_count and returns 0 if >= threshold, else 1
# ------------------------------------------------------------
is_plex_transcoding_over_threshold() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking Plex transcodes..."

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

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Found $total_local local & $total_remote remote => total=$total_count, threshold=$TRANSCODE_THRESHOLD"

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
# If watchers=0 => desired=5, watchers=3 => desired=2, etc.
# If we get an error, we re-check the Node log for a changed ID.
# ------------------------------------------------------------
adjust_tdarr_workers() {
    # Make sure we have a nodeID
    ensure_node_id_loaded || return

    local watchers="$1"
    local desired=$((TDARR_DEFAULT_LIMIT - watchers))
    [ "$desired" -lt 0 ] && desired=0

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Adjusting GPU workers. watchers=$watchers => desired=$desired"

    # poll-worker-limits
    local poll_resp
    poll_resp=$(curl -s -X POST "${TDARR_API_URL}/api/v2/poll-worker-limits" \
        -H "Content-Type: application/json" \
        -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'"}}')

    local current
    current=$(echo "$poll_resp" | jq '.workerLimits.transcodegpu' 2>/dev/null)
    if [ -z "$current" ] || [ "$current" = "null" ]; then
        echo "ERROR: Could not retrieve current GPU worker limit for nodeID='$TDARR_NODE_ID'. Will re-check log for a new ID."
        refresh_node_id_if_changed
        return
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Current GPU worker limit: $current"

    local diff=$(( desired - current ))
    if [ "$diff" -eq 0 ]; then
        echo "Already at the desired GPU worker limit ($desired)."
        return
    fi

    local step
    if [ "$diff" -gt 0 ]; then
        step="increase"
        echo "Need to increase by $diff"
    else
        step="decrease"
        diff=$(( -diff ))
        echo "Need to decrease by $diff"
    fi

    local i=0
    while [ $i -lt $diff ]; do
        curl -s -X POST "${TDARR_API_URL}/api/v2/alter-worker-limit" \
            -H "Content-Type: application/json" \
            -d '{"data":{"nodeID":"'"$TDARR_NODE_ID"'","process":"'"$step"'","workerType":"transcodegpu"}}' \
            >/dev/null 2>&1
        i=$(( i + 1 ))
        sleep 1  # optional delay
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') - GPU worker limit adjustment complete."
}


# ------------------------------------------------------------
# Main Script
# ------------------------------------------------------------

# 1) Try to load a nodeID at startup (not strictly required, but nice to do once).
ensure_node_id_loaded

# 2) Check Tautulli connectivity
check_tautulli_connections_on_startup

# 3) Main monitoring loop
while true; do

    if is_plex_transcoding_over_threshold; then
        # watchers >= threshold
        if [ "$TDARR_ALTER_WORKERS" = "true" ]; then
            echo "Threshold exceeded. Reducing GPU workers."
            adjust_tdarr_workers "$total_count"
            sleep "$WAIT_SECONDS"
        else
            # kill container
            if is_container_running; then
                echo "Threshold exceeded: Killing $CONTAINER_NAME"
                docker kill "$CONTAINER_NAME"
            else
                echo "$CONTAINER_NAME is already stopped."
            fi
            sleep "$WAIT_SECONDS"
        fi
    else
        # watchers < threshold
        if [ "$TDARR_ALTER_WORKERS" = "true" ]; then
            adjust_tdarr_workers "$total_count"
        fi

        if ! is_container_running; then
            echo "Below threshold -> Starting container $CONTAINER_NAME."
            docker start "$CONTAINER_NAME"
        else
            echo "Container $CONTAINER_NAME is already running."
        fi

        sleep "$BASIC_CHECK"
    fi
done
