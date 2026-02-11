#!/bin/bash

# ==========================================
# CONFIGURATION & VARIABLES
# ==========================================

# Logging Tag (referenced as -t in logger commands)
LOG_TAG="smartbat"

# Battery 0 Control Node (Internal Battery)
BAT0_CTRL="/sys/class/power_supply/BAT0/charge_behaviour"

# Target % for External Battery (BAT1)
# Dynamically fetches the 'STOP_CHARGE_THRESH_BAT1' value from TLP config.
# If fetch fails, defaults to 85.
BAT1_TARGET=$(tlp-stat -c | grep "STOP_CHARGE_THRESH_BAT1=" | awk -F= '{print $2}' | tr -d '"')
if [[ -z "$BAT1_TARGET" ]]; then
    BAT1_TARGET=85
    logger -t "$LOG_TAG" "WARNING: Could not fetch TLP threshold. Defaulting to 85%."
fi

# ==========================================
# SENSORS & SYSTEM STATE
# ==========================================

# 1. Wait for TLP/System to Settle
# Prevents race conditions when plugging in AC.
sleep 2

# 2. Check AC Power Status
# Handles standard AC or ThinkPad 'ACAD' naming.
if [ -f "/sys/class/power_supply/AC/online" ]; then
    AC_ON=$(cat /sys/class/power_supply/AC/online)
else
    AC_ON=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo "0")
fi

# 3. Check Battery 1 Capacity
if [ -f "/sys/class/power_supply/BAT1/capacity" ]; then
    BAT1_CAP=$(cat /sys/class/power_supply/BAT1/capacity)
else
    BAT1_CAP="ERR"
fi

# 4. Check Current BAT0 Behavior
# Reads the current status to avoid redundant writes.
if [ -f "$BAT0_CTRL" ]; then
    CURRENT_BEHAVIOUR=$(cat "$BAT0_CTRL")
else
    CURRENT_BEHAVIOUR="NOT_FOUND"
fi

# ==========================================
# LOGIC & EXECUTION
# ==========================================

# Log the diagnostic state
logger -t "$LOG_TAG" "DIAGNOSTIC: AC=$AC_ON | BAT1=$BAT1_CAP% (Target $BAT1_TARGET%) | BAT0_Current=$CURRENT_BEHAVIOUR"

if [ "$AC_ON" = "1" ]; then
    # --- AC CONNECTED ---
    
    if [ "$BAT1_CAP" == "ERR" ]; then
         logger -t "$LOG_TAG" "ERROR: BAT1 sensor not found. Taking no action."
         exit 1
    fi

    if [ "$BAT1_CAP" -ge "$BAT1_TARGET" ]; then
        # DECISION: RELEASE BAT0 (BAT1 is Full/Sufficient)
        
        # Check if already [auto] to prevent log spam/redundant writes
        if [[ "$CURRENT_BEHAVIOUR" == *"[auto]"* ]]; then
             logger -t "$LOG_TAG" "NO-OP: BAT1 sufficient, and BAT0 is already [auto]."
        else
             logger -t "$LOG_TAG" "ACTION: BAT1 sufficient ($BAT1_CAP% >= $BAT1_TARGET%). Switching BAT0 to AUTO."
             # echo "auto" > "$BAT0_CTRL"
        fi
    else
        # DECISION: INHIBIT BAT0 (BAT1 Needs Priority)
        
        # Check if already [inhibit-charge]
        if [[ "$CURRENT_BEHAVIOUR" == *"[inhibit-charge]"* ]]; then
             logger -t "$LOG_TAG" "NO-OP: BAT1 low, and BAT0 is already [inhibit-charge]."
        else
             logger -t "$LOG_TAG" "ACTION: BAT1 low ($BAT1_CAP% < $BAT1_TARGET%). Switching BAT0 to INHIBIT-CHARGE."
             # echo "inhibit-charge" > "$BAT0_CTRL"
        fi
    fi

else
    # --- AC DISCONNECTED ---
    
    # Emergency Fail-safe: Ensure BAT0 is available for discharge
    if [[ "$CURRENT_BEHAVIOUR" == *"[auto]"* ]]; then
         logger -t "$LOG_TAG" "NO-OP: On Battery, and BAT0 is already [auto]."
    else
         logger -t "$LOG_TAG" "ACTION: Power lost. Emergency release of BAT0 to AUTO."
         # echo "auto" > "$BAT0_CTRL"
    fi
fi
