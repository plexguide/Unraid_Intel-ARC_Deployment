#!/bin/bash
# Adjust SABnzbd Speed Limit Based on Tautulli Remote Bandwidth Usage (Looping)
# -------------------------------------------------------------------
# This script continuously queries Tautulli for Plex activity, counts remote
# sessions, sums their total bandwidth usage, rounds the total up to the nearest MB,
# and adjusts SABnzbd’s speed limit accordingly.
#
# It also verifies Tautulli returns a valid JSON structure. If Tautulli is
# unreachable or the address is fake, it will log an error instead of claiming success.
#
# -------------------------------------------------------------------
# Configuration Variables:
# -------------------------------------------------------------------

# Tautulli API configuration:
TAUTULLI_API_KEY="dad9bbb78bde43249754b630b58fbf7c"
TAUTULLI_URL="http://10.0.0.10:8181/api/v2"  # Make sure protocol & domain are correct!

# SABnzbd API configuration:
SAB_ADDRESS="http://10.0.0.10:8080" 
SAB_API_KEY="86a11e19dcb1400a869773be38abc9bf"

# Speed limit settings:
BASE_SPEED_LIMIT_MB=50    # Base SABnzbd speed limit in MB/s
OFFSET_PER_USER_MB=5      # Reduce speed by X MB/s for each remote user
MIN_SPEED_MB=10           # Minimum speed limit in MB/s

# Local network configuration:
LOCAL_IP_PREFIX="10.0.0."

# Loop interval:
WAIT_INTERVAL=3  # Seconds between checks

# -------------------------------------------------------------------
# Logging Function
# -------------------------------------------------------------------
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# -------------------------------------------------------------------
# check_tautulli_connection:
#   Confirms Tautulli returns HTTP 200 and valid JSON with .response.data.sessions
# -------------------------------------------------------------------
check_tautulli_connection() {
    log_message "Checking connection to Tautulli API at ${TAUTULLI_URL}"
    
    # Make a request, capture HTTP status & body separately
    http_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -o /tmp/tautulli_check.json \
        "${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity")
    
    # Extract the status code
    status_code=$(echo "$http_response" | sed -n 's/.*HTTPSTATUS://p')
    # Read the response body from the temp file
    body=$(cat /tmp/tautulli_check.json)

    if [ "$status_code" -ne 200 ]; then
        log_message "ERROR: Tautulli returned HTTP status $status_code. Check your URL or API key."
        return 1
    fi
    
    # Ensure we have the key .response.data.sessions in the JSON
    if ! echo "$body" | jq -e '.response.data.sessions' >/dev/null 2>&1; then
        log_message "ERROR: Tautulli's JSON is missing .response.data.sessions. Possibly an invalid response."
        return 1
    fi
    
    log_message "Successfully connected to Tautulli."
    return 0
}

# -------------------------------------------------------------------
# adjust_sab_speed_limit:
#   Retrieves current Tautulli data, calculates new SAB speed,
#   and updates SABnzbd using the 4.4 API format.
# -------------------------------------------------------------------
adjust_sab_speed_limit() {
    # Make a fresh request for current Tautulli data
    http_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -o /tmp/tautulli_data.json \
        "${TAUTULLI_URL}?apikey=${TAUTULLI_API_KEY}&cmd=get_activity")
    
    status_code=$(echo "$http_response" | sed -n 's/.*HTTPSTATUS://p')
    body=$(cat /tmp/tautulli_data.json)

    if [ "$status_code" -ne 200 ]; then
        log_message "ERROR: Tautulli returned HTTP status $status_code. Skipping SABnzbd update."
        return
    fi
    
    # Check that the JSON structure is correct
    if ! echo "$body" | jq -e '.response.data.sessions' >/dev/null 2>&1; then
        log_message "ERROR: Tautulli's JSON is missing .response.data.sessions. Skipping SABnzbd update."
        return
    fi
    
    # Count remote sessions (where IP does not start with LOCAL_IP_PREFIX)
    remote_count=$(echo "$body" | jq "[.response.data.sessions[]? 
        | select(.ip_address | startswith(\"${LOCAL_IP_PREFIX}\") | not)] 
        | length")

    # Sum the remote sessions' bandwidth
    total_bandwidth=$(echo "$body" | jq "[.response.data.sessions[]? 
        | select(.ip_address | startswith(\"${LOCAL_IP_PREFIX}\") | not) 
        | .bandwidth] 
        | add")

    if [ -z "$total_bandwidth" ] || [ "$total_bandwidth" = "null" ]; then
        total_bandwidth=0
    fi
    
    # Round up to the nearest integer
    rounded_bandwidth=$(echo "$total_bandwidth" | awk '{if($1==int($1)){print $1}else{print int($1)+1}}')
    
    log_message "Detected ${remote_count} remote streaming session(s) with a total bandwidth of ${rounded_bandwidth} MB/s."

    # Subtract both the per-user offset and the total remote bandwidth
    reduction=$(( remote_count * OFFSET_PER_USER_MB ))
    new_speed=$(( BASE_SPEED_LIMIT_MB - reduction - rounded_bandwidth ))
    
    if [ "$new_speed" -lt "$MIN_SPEED_MB" ]; then
        new_speed=$MIN_SPEED_MB
    fi
    
    # Log the calculation details first
    log_message "(Base: ${BASE_SPEED_LIMIT_MB} MB/s, Offset: ${remote_count} x ${OFFSET_PER_USER_MB} MB/s, Remote BW: ${rounded_bandwidth} MB/s)"
    # Then log the final speed
    log_message "Calculated new SABnzbd speed limit: ${new_speed} MB/s"

    # Update SABnzbd
    sab_api_url="${SAB_ADDRESS}/api?mode=config&name=speedlimit&apikey=${SAB_API_KEY}&value=${new_speed}M"
    log_message "Sending SABnzbd API request: ${sab_api_url}"

    sab_response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$sab_api_url")
    sab_body=$(echo "$sab_response" | sed -e 's/HTTPSTATUS\:.*//g')
    sab_status=$(echo "$sab_response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$sab_status" -eq 200 ]; then
        log_message "SABnzbd speed limit successfully updated. Response: ${sab_body}"
    else
        log_message "Error updating SABnzbd speed limit. HTTP status: ${sab_status}, Response: ${sab_body}"
    fi
}

# -------------------------------------------------------------------
# Main Execution Loop
# -------------------------------------------------------------------
while true; do
    # First confirm Tautulli is actually reachable & returning valid JSON
    if ! check_tautulli_connection; then
        log_message "Skipping speed adjustment due to Tautulli connection error."
    else
        # If Tautulli is valid, do the speed adjustment
        adjust_sab_speed_limit
    fi
    
    log_message "Waiting for ${WAIT_INTERVAL} seconds before next check..."
    echo ""
    sleep "${WAIT_INTERVAL}"
done
