#!/bin/bash
# ~/.config/hypr/UserScripts/BatteryNotifier.sh 13 Nov at 11:43:57 AM
# Enhanced battery notifier with full sound support

# VARIABLES
LOW_BAT=20
CRITICAL_BAT=10
FULL_BAT=95
STATE_FILE="$HOME/.config/hypr/UserScripts/.battery_state"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "UNKNOWN" > "$STATE_FILE"
fi

# Function to show notification
show_notification() {
    local message="$1"
    local urgency="$2"
    notify-send "Battery" "$message" -u "$urgency"
}

while true; do
    # Find the first available battery
    BATTERY_PATH=""
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

        # Battery plugged in (charging)
        if [ "$STATUS" == "Charging" ] && [ "$LAST_STATE" != "CHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --charging
            show_notification "Charger plugged in - Battery charging ($CAPACITY%)" "low"
            echo "CHARGING" > "$STATE_FILE"
        
        # Battery unplugged (discharging)
        elif [ "$STATUS" == "Discharging" ] && [ "$LAST_STATE" != "DISCHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --discharging
            show_notification "Charger unplugged - Running on battery ($CAPACITY%)" "low"
            echo "DISCHARGING" > "$STATE_FILE"
        
        # Critical battery warning
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$CRITICAL_BAT" ] && [ "$LAST_STATE" != "CRITICAL" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --critical-battery
            show_notification "CRITICAL: Battery at $CAPACITY% - Plug in immediately!" "critical"
            echo "CRITICAL" > "$STATE_FILE"
        
        # Low battery warning
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$LOW_BAT" ] && [ "$LAST_STATE" != "LOW" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --low-battery
            show_notification "Low battery: $CAPACITY% - Please plug in charger" "normal"
            echo "LOW" > "$STATE_FILE"
        
        # Battery fully charged
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -ge "$FULL_BAT" ] && [ "$LAST_STATE" != "FULL" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --full-battery
            show_notification "Battery fully charged: $CAPACITY%" "low"
            echo "FULL" > "$STATE_FILE"
        
        # Reset state when battery is no longer low but was previously
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -gt "$LOW_BAT" ] && [ "$LAST_STATE" == "LOW" ]; then
            echo "CHARGING" > "$STATE_FILE"
        
        # Reset state when battery is no longer critical but was previously
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -gt "$CRITICAL_BAT" ] && [ "$LAST_STATE" == "CRITICAL" ]; then
            echo "CHARGING" > "$STATE_FILE"
        fi
    fi

    sleep 60 # Check every 60 seconds
done
