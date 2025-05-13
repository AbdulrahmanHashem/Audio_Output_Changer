#!/bin/bash
# ==============================================================================
# Description: Switches the audio output port for a target audio sink
#              between two predefined ports (e.g., Line Out and Headphones).
#              By default, targets the system's default sink, but can be
#              easily modified to target a manually specified sink number.
#
# Dependencies: pactl, awk, (optional: notify-send for desktop notifications)
# Output: Prints informational messages and errors.
# Exit Codes:
#   0: Success
#   1: Failure
# ==============================================================================

# --- Script Setup ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Ensure pipeline failures are reported correctly.
set -o pipefail

# --- Configuration ---
# User-configurable port names. Ensure these match the output of 'pactl list sinks'.
PORT1_NAME="analog-output-lineout"    # Represents your primary/first port
PORT2_NAME="analog-output-headphones" # Represents your secondary/second port

# Friendly names for notifications.
PORT1_FRIENDLY_NAME="Line Out"
PORT2_FRIENDLY_NAME="Headphones"

# --- Reusable Helper Functions ---
log_info() {
    echo "[INFO] $1"
}
log_error() {
    echo "[ERROR] $1" >&2
}
send_notification() {
    if command -v notify-send &> /dev/null; then
        local title="$1"
        local message="$2"
        local expire_time="${3:-3000}"
        local icon_name="$4"
        local icon_option=""
        if [ -n "$icon_name" ]; then icon_option="--icon=$icon_name"; fi
        notify-send --expire-time="$expire_time" $icon_option "$title" "$message"
    fi
}

# --- Dependency Check ---
if ! command -v pactl &> /dev/null; then
    log_error "'pactl' command not found. Please install the necessary package."
    exit 1
fi
if ! command -v awk &> /dev/null; then
    log_error "'awk' command not found. Please install a suitable awk implementation."
    exit 1
fi

# --- Initial System Data Fetch ---
# Fetch all sink information ONCE early on, as it might be needed by
# both dynamic detection and the switching logic.
log_info "Fetching sink information..."
ALL_SINKS_INFO=$(pactl list sinks) || {
    log_error "Failed to get output from 'pactl list sinks'. Is PulseAudio/PipeWire running?"
    send_notification "Audio Switch Error" "Failed to get sink information" 4000 "dialog-error"
    exit 1
}
if [ -z "$ALL_SINKS_INFO" ]; then
    log_error "'pactl list sinks' produced no output."
    send_notification "Audio Switch Error" "No sink information found" 4000 "dialog-error"
    exit 1
fi

# =================================================================================================
# SECTION A: DETERMINE TARGET SINK IDENTIFIER (SINK_IDENTIFIER)
# Choose ONE of the following methods:
# =================================================================================================

# --- METHOD 1: Dynamic - Use Default Sink (Uncomment this block to use) ---
# This section finds the number of the system's current default sink.
# To use this method, ensure this block is UNCOMMENTED and "METHOD 2" is COMMENTED OUT.
# ------------------------------------------------------------------------------
log_info "Determining the number of the default audio sink..."
# 1.1 Get the default sink name
DEFAULT_SINK_NAME=$(pactl get-default-sink) || {
    log_error "Failed to execute 'pactl get-default-sink'."
    send_notification "Audio Switch Error" "Could not get default sink name" 4000 "dialog-error"
    exit 1
}
if [ -z "$DEFAULT_SINK_NAME" ]; then
    log_error "'pactl get-default-sink' returned an empty name."
    send_notification "Audio Switch Error" "Default sink name is empty" 4000 "dialog-error"
    exit 1
fi
log_info "Default sink name is: '$DEFAULT_SINK_NAME'."
# 1.2 Find the number corresponding to the default name
SINK_IDENTIFIER=$(echo "$ALL_SINKS_INFO" | awk -v name="$DEFAULT_SINK_NAME" '
    /^Sink #/ { current_sink_num = $2; sub(/^#/, "", current_sink_num); next }
    (current_sink_num != "") && ($1 == "Name:" && $2 == name) { print current_sink_num; found = 1; exit 0; }
    /^\s*$/ { current_sink_num = ""; next }
    END { if (found != 1) exit 1 }
')
# If awk fails to find the name and exits 1, 'set -e' will terminate the script here.
# ------------------------------------------------------------------------------
# --- End METHOD 1 ---


# --- METHOD 2: Manual - Specify Sink Number (Uncomment this line to use) ---
# If you prefer to always target a specific sink number, COMMENT OUT the entire
# "METHOD 1" block above and UNCOMMENT the following line, replacing '57'
# with the desired sink number from 'pactl list sinks'.
# ------------------------------------------------------------------------------
# SINK_IDENTIFIER="57" # <<< Replace 57 with your target sink number
# ------------------------------------------------------------------------------
# --- End METHOD 2 ---


# --- VALIDATION of SINK_IDENTIFIER (Applies to both methods) ---
# Ensure that SINK_IDENTIFIER is set and is a valid number before proceeding.
if [ -z "$SINK_IDENTIFIER" ]; then
    log_error "SINK_IDENTIFIER was not set. Ensure either Method 1 or Method 2 above is active and successful."
    exit 1
fi
if ! [[ "$SINK_IDENTIFIER" =~ ^[0-9]+$ ]]; then
    log_error "The determined SINK_IDENTIFIER ('$SINK_IDENTIFIER') is not a valid number."
    send_notification "Audio Switch Error" "Invalid Sink ID determined ('$SINK_IDENTIFIER')" 4000 "dialog-error"
    exit 1
fi
log_info "Using target SINK_IDENTIFIER: $SINK_IDENTIFIER"
# --- End VALIDATION ---

# =================================================================================================
# SECTION B: AUDIO PORT SWITCHING LOGIC
# (This part uses the SINK_IDENTIFIER determined in SECTION A)
# =================================================================================================
log_info "Proceeding with audio port switching logic for Sink #$SINK_IDENTIFIER..."

# 2.1 Port Name General Availability Check (Optional config sanity check)
log_info "Checking general availability of configured port names '$PORT1_NAME' and '$PORT2_NAME'..."
port1_name_exists_globally=false
port2_name_exists_globally=false
if echo "$ALL_SINKS_INFO" | grep -q -F -- "$PORT1_NAME"; then port1_name_exists_globally=true; fi
if echo "$ALL_SINKS_INFO" | grep -q -F -- "$PORT2_NAME"; then port2_name_exists_globally=true; fi

if ! $port1_name_exists_globally || ! $port2_name_exists_globally; then
    # Log errors only if missing, proceed otherwise unless both missing.
    if ! $port1_name_exists_globally; then log_error "Configured PORT1_NAME '$PORT1_NAME' not found in system sink list."; fi
    if ! $port2_name_exists_globally; then log_error "Configured PORT2_NAME '$PORT2_NAME' not found in system sink list."; fi
    log_error "One or both configured port names missing globally. Check configuration."
    exit 1
fi
log_info "Both configured port names exist somewhere in the system sink list."

# 2.2 Detect the current active port for the target SINK_IDENTIFIER.
# Uses the SINK_IDENTIFIER number and the stored ALL_SINKS_INFO.
CURRENT_PORT=$(echo "$ALL_SINKS_INFO" | sed -n "/^Sink #${SINK_IDENTIFIER}[[:space:]]*$/,/^$/p" | grep '^\s*Active Port:' | awk '{print $3}')

# 2.3 Check if CURRENT_PORT was successfully populated.
if [ -z "$CURRENT_PORT" ]; then
    # The previous fallback logic based on SINK_IDENTIFIER containing "." is removed
    # as it's not applicable when SINK_IDENTIFIER is always determined as a number.
    # If the primary method fails, we now consider it an error.
    log_error "Could not detect current active port for Sink #$SINK_IDENTIFIER using primary method."
    send_notification "Audio Switch Error" "Could not detect active port for Sink #$SINK_IDENTIFIER" 4000 "dialog-error"
    exit 1
fi
log_info "Current active port for Sink #$SINK_IDENTIFIER is '$CURRENT_PORT'."

# 2.4 Decide which port to switch to based on the current active port.
TARGET_PORT=""
TARGET_PORT_FRIENDLY=""

if [ "$CURRENT_PORT" == "$PORT1_NAME" ]; then
    TARGET_PORT="$PORT2_NAME"
    TARGET_PORT_FRIENDLY="$PORT2_FRIENDLY_NAME"
elif [ "$CURRENT_PORT" == "$PORT2_NAME" ]; then
    TARGET_PORT="$PORT1_NAME"
    TARGET_PORT_FRIENDLY="$PORT1_FRIENDLY_NAME"
else
    # Current port is unexpected. Defaulting to switch to PORT1.
    # Consider adding a check here to ensure PORT1_NAME is valid for this sink if needed.
    log_info "Warning: Current port '$CURRENT_PORT' is unexpected for Sink #$SINK_IDENTIFIER. Attempting default switch to '$PORT1_NAME'."
    TARGET_PORT="$PORT1_NAME"
    TARGET_PORT_FRIENDLY="$PORT1_FRIENDLY_NAME"
fi
log_info "Target port set to '$TARGET_PORT' ($TARGET_PORT_FRIENDLY)."

# 2.5 Set the new active port for the target sink.
log_info "Attempting to switch Sink #$SINK_IDENTIFIER to port '$TARGET_PORT'..."
pactl set-sink-port "$SINK_IDENTIFIER" "$TARGET_PORT" || {
    log_error "'pactl set-sink-port' command failed for Sink #$SINK_IDENTIFIER and port '$TARGET_PORT'."
    send_notification "Audio Switch Error" "Failed to set port to '$TARGET_PORT_FRIENDLY'" 3000 "dialog-error"
    exit 1
}

# --- Success ---
log_info "Audio output port for Sink #$SINK_IDENTIFIER successfully set to: $TARGET_PORT"
send_notification "Audio Port Changed" "Switched to: $TARGET_PORT_FRIENDLY" 2000 "audio-headphones"

exit 0
