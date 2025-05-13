#!/bin/bash
# ==============================================================================
# Description: Finds the system's default audio output sink number using pactl,
#              determines the associated ALSA card number for that sink,
#              and then uses amixer to disable 'Auto-Mute Mode' on that card.
#
# Dependencies: pactl, amixer, awk
# Output: Prints informational messages and errors.
# Exit Codes:
#   0: Success
#   1: Failure
# ==============================================================================

# --- Script Setup ---
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # Ensure pipeline failures are reported correctly.

# --- Configuration ---
CONTROL_NAME='Auto-Mute Mode' # The ALSA control name we want to change
TARGET_STATE='Disabled'       # The desired state

# --- Reusable Helper Functions (borrowed style) ---
log_info() {
    echo "[INFO] $1"
}
log_error() {
    echo "[ERROR] $1" >&2
}

# --- Dependency Check ---
if ! command -v pactl &> /dev/null; then
    log_error "'pactl' command not found. Please install the necessary package (e.g., pulseaudio-utils or pipewire-pulse)."
    exit 1
fi
if ! command -v awk &> /dev/null; then
    log_error "'awk' command not found. Please install a suitable awk implementation."
    exit 1
fi
if ! command -v amixer &> /dev/null; then
    log_error "'amixer' command not found. Please install alsa-utils."
    exit 1
fi

# --- Initial System Data Fetch ---
# Fetch all sink information ONCE, needed for multiple steps.
log_info "Fetching sink information..."
ALL_SINKS_INFO=$(pactl list sinks) || {
    log_error "Failed to get output from 'pactl list sinks'. Is PulseAudio/PipeWire running?"
    exit 1
}
if [ -z "$ALL_SINKS_INFO" ]; then
    log_error "'pactl list sinks' produced no output."
    exit 1
fi

# =================================================================================================
# SECTION A: DETERMINE TARGET SINK NUMBER (SINK_IDENTIFIER)
# (Using Method 1 logic from your provided script)
# =================================================================================================
log_info "Determining the number of the default audio sink..."
# A.1 Get the default sink name
DEFAULT_SINK_NAME=$(pactl get-default-sink) || {
    log_error "Failed to execute 'pactl get-default-sink'."
    exit 1
}
if [ -z "$DEFAULT_SINK_NAME" ]; then
    log_error "'pactl get-default-sink' returned an empty name."
    exit 1
fi
log_info "Default sink name is: '$DEFAULT_SINK_NAME'."

# A.2 Find the number corresponding to the default name using awk
SINK_IDENTIFIER=$(echo "$ALL_SINKS_INFO" | awk -v name="$DEFAULT_SINK_NAME" '
    BEGIN { found = 0 } # Initialize found flag
    /^Sink #/ { current_sink_num = $2; sub(/^#/, "", current_sink_num); next } # Get sink number
    (current_sink_num != "") && ($1 == "Name:" && $2 == name) { print current_sink_num; found = 1; exit 0; } # Match name and print number
    /^\s*$/ { current_sink_num = ""; next } # Reset on blank line
    END { if (found != 1) exit 1 } # Exit with error if name not found
') || { # Handle awk exit status directly
    log_error "Could not find Sink Number corresponding to default sink name '$DEFAULT_SINK_NAME'."
    exit 1
}

# A.3 VALIDATION of SINK_IDENTIFIER
if ! [[ "$SINK_IDENTIFIER" =~ ^[0-9]+$ ]]; then
    log_error "The determined SINK_IDENTIFIER ('$SINK_IDENTIFIER') is not a valid number."
    exit 1
fi
log_info "Using target SINK_IDENTIFIER (Sink #): $SINK_IDENTIFIER"

# =================================================================================================
# SECTION B: DETERMINE ALSA CARD NUMBER FROM SINK_IDENTIFIER
# =================================================================================================
log_info "Finding ALSA card number associated with Sink #$SINK_IDENTIFIER..."

# B.1 Parse the specific block for the target sink number to find 'alsa.card' or 'device.string'
# Use sed to isolate the block for the target sink, then awk to find the property.
CARD_NUMBER=$(echo "$ALL_SINKS_INFO" |
               sed -n "/^Sink #${SINK_IDENTIFIER}[[:space:]]*$/,/^\s*Sink #\|^$/p" | # Extract block for Sink #ID until next sink or blank line
               awk '
                   /alsa.card = "/ { gsub(/"/, "", $NF); print $NF; found=1; exit }
                   /device.string = "hw:[0-9]+"/ { gsub(/.*hw:|"/,""); print; found=1; exit }
                   END { if (!found) exit 1 } # Exit with error if neither property found in the block
               ') || {
                   log_error "Could not determine ALSA card number for Sink #$SINK_IDENTIFIER from its properties."
                   log_error "Check 'pactl list sinks' output for 'alsa.card =' or 'device.string = \"hw:N\"' within that sink's block."
                   exit 1
               }

# B.2 VALIDATION of CARD_NUMBER (Optional, but good practice)
if ! [[ "$CARD_NUMBER" =~ ^[0-9]+$ ]]; then
    log_error "The determined CARD_NUMBER ('$CARD_NUMBER') associated with Sink #$SINK_IDENTIFIER is not a valid number."
    exit 1
fi
log_info "Found ALSA card number: $CARD_NUMBER"

# =================================================================================================
# SECTION C: EXECUTE AMIXER COMMAND
# =================================================================================================
log_info "Attempting to set ALSA control '$CONTROL_NAME' on card $CARD_NUMBER to '$TARGET_STATE'..."

# C.1 Execute amixer command, checking specifically if the control exists if it fails.
if amixer -c "$CARD_NUMBER" sset "$CONTROL_NAME" "$TARGET_STATE"; then
    log_info "'$CONTROL_NAME' successfully set to '$TARGET_STATE' on card $CARD_NUMBER."
else
    # If amixer failed, check if the reason was that the control doesn't exist
    if ! amixer -c "$CARD_NUMBER" scontrols | grep -qF "'$CONTROL_NAME'"; then
        log_error "Control '$CONTROL_NAME' was NOT found on ALSA card $CARD_NUMBER."
        log_info "Available controls on card $CARD_NUMBER:"
        amixer -c "$CARD_NUMBER" scontrols # List available controls to help diagnose
        exit 1 # Exit with error because the control is missing
    else
        # The control exists, but amixer failed for some other reason
        log_error "'amixer sset' command failed for card $CARD_NUMBER, control '$CONTROL_NAME'. Check previous errors or permissions."
        exit 1 # Exit with error for other amixer failures
    fi
fi

# --- Success ---
exit 0
