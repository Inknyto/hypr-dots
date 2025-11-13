#!/bin/bash

# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Battery notification script

# VARIABLES
LOW_BAT=20
STATE_FILE="$HOME/.config/hypr/UserScripts/.battery_state"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "UNKNOWN" > "$STATE_FILE"
fi

while true; do
    # Find the first available battery
    for i in {0..3}; do
        if [ -f "/sys/class/power_supply/BAT$i/capacity" ]; then
            BATTERY_PATH="/sys/class/power_supply/BAT$i"
            break
        fi
    done

    if [ -n "$BATTERY_PATH" ]; then
        STATUS=$(cat "$BATTERY_PATH/status")
        CAPACITY=$(cat "$BATTERY_PATH/capacity")
        LAST_STATE=$(cat "$STATE_FILE")

        if [ "$STATUS" == "Charging" ] && [ "$LAST_STATE" != "CHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --charging
            echo "CHARGING" > "$STATE_FILE"
        elif [ "$STATUS" == "Discharging" ] && [ "$LAST_STATE" != "DISCHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --discharging
            echo "DISCHARGING" > "$STATE_FILE"
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$LOW_BAT" ] && [ "$LAST_STATE" != "LOW" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --low-battery
            echo "LOW" > "$STATE_FILE"
        fi
    fi

    sleep 60 # Check every 60 seconds
done
