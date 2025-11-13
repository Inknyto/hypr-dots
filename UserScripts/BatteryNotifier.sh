#!/bin/bash
# ~/.config/hypr/UserScripts/BatteryNotifier.sh 13 Nov at 12:43:31 PM
# Enhanced battery notifier with complete sound and visual notifications

# VARIABLES
LOW_BAT=20
CRITICAL_BAT=10
FULL_BAT=95
STATE_FILE="$HOME/.config/hypr/UserScripts/.battery_state"

# Notification icons (using system icons - adjust if needed)
ICON_CHARGING="battery-charging"
ICON_DISCHARGING="battery"
ICON_LOW="battery-low"
ICON_CRITICAL="battery-empty"
ICON_FULL="battery-full"
ICON_PLUGGED="ac-adapter"
ICON_UNPLUGGED="battery"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "UNKNOWN" > "$STATE_FILE"
fi

# Function to show notification with proper styling
show_notification() {
    local message="$1"
    local urgency="$2"
    local icon="$3"
    local timeout="$4"
    
    # Default timeout based on urgency
    if [ -z "$timeout" ]; then
        case "$urgency" in
            "critical") timeout=0 ;; # Stays until dismissed
            "normal") timeout=5000 ;; # 5 seconds
            "low") timeout=3000 ;; # 3 seconds
            *) timeout=3000 ;;
        esac
    fi
    
    notify-send \
        -i "$icon" \
        -u "$urgency" \
        -t "$timeout" \
        "Battery Status" \
        "$message"
}

# Function to get battery info for notifications
get_battery_info() {
    local capacity="$1"
    local status="$2"
    local time_remaining=""
    
    # Try to get time remaining if available
    if [ -f "$BATTERY_PATH/capacity" ] && [ -f "$BATTERY_PATH/status" ]; then
        if [ "$status" == "Discharging" ] && [ -f "$BATTERY_PATH/power_now" ]; then
            power_now=$(cat "$BATTERY_PATH/power_now" 2>/dev/null)
            energy_now=$(cat "$BATTERY_PATH/energy_now" 2>/dev/null)
            if [ -n "$power_now" ] && [ -n "$energy_now" ] && [ "$power_now" -gt 0 ]; then
                minutes=$((energy_now * 60 / power_now))
                time_remaining=" (~$((minutes/60))h$((minutes%60))m)"
            fi
        elif [ "$status" == "Charging" ] && [ -f "$BATTERY_PATH/power_now" ]; then
            power_now=$(cat "$BATTERY_PATH/power_now" 2>/dev/null)
            energy_full=$(cat "$BATTERY_PATH/energy_full" 2>/dev/null)
            energy_now=$(cat "$BATTERY_PATH/energy_now" 2>/dev/null)
            if [ -n "$power_now" ] && [ -n "$energy_full" ] && [ -n "$energy_now" ] && [ "$power_now" -gt 0 ]; then
                minutes=$(( (energy_full - energy_now) * 60 / power_now ))
                time_remaining=" (~$((minutes/60))h$((minutes%60))m until full)"
            fi
        fi
    fi
    
    echo "$time_remaining"
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
        TIME_REMAINING=$(get_battery_info "$CAPACITY" "$STATUS")

        # Battery plugged in (charging)
        if [ "$STATUS" == "Charging" ] && [ "$LAST_STATE" != "CHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --charging
            show_notification "⚡ Charger connected\nBattery: $CAPACITY%$TIME_REMAINING" "low" "$ICON_CHARGING" 3000
            echo "CHARGING" > "$STATE_FILE"
        
        # Battery unplugged (discharging)
        elif [ "$STATUS" == "Discharging" ] && [ "$LAST_STATE" != "DISCHARGING" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --discharging
            show_notification "🔋 Running on battery\nBattery: $CAPACITY%$TIME_REMAINING" "low" "$ICON_DISCHARGING" 3000
            echo "DISCHARGING" > "$STATE_FILE"
        
        # Critical battery warning
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$CRITICAL_BAT" ] && [ "$LAST_STATE" != "CRITICAL" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --critical-battery
            show_notification "🚨 CRITICAL BATTERY!\nOnly $CAPACITY% remaining!\nPlug in charger immediately!$TIME_REMAINING" "critical" "$ICON_CRITICAL" 0
            echo "CRITICAL" > "$STATE_FILE"
        
        # Low battery warning
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$LOW_BAT" ] && [ "$LAST_STATE" != "LOW" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --low-battery
            show_notification "⚠️ Low battery\nBattery: $CAPACITY%\nPlease connect charger soon$TIME_REMAINING" "normal" "$ICON_LOW" 8000
            echo "LOW" > "$STATE_FILE"
        
        # Battery fully charged
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -ge "$FULL_BAT" ] && [ "$LAST_STATE" != "FULL" ]; then
            "$HOME/.config/hypr/scripts/Sounds.sh" --full-battery
            show_notification "✅ Battery fully charged\nBattery: $CAPACITY%\nYou can unplug the charger" "low" "$ICON_FULL" 5000
            echo "FULL" > "$STATE_FILE"
        
        # Reset state when battery is no longer low but was previously
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -gt "$LOW_BAT" ] && [ "$LAST_STATE" == "LOW" ]; then
            show_notification "🔋 Battery recovering\nBattery: $CAPACITY%\nNo longer in low battery state" "low" "$ICON_CHARGING" 3000
            echo "CHARGING" > "$STATE_FILE"
        
        # Reset state when battery is no longer critical but was previously
        elif [ "$STATUS" == "Charging" ] && [ "$CAPACITY" -gt "$CRITICAL_BAT" ] && [ "$LAST_STATE" == "CRITICAL" ]; then
            show_notification "⚡ Battery recovering\nBattery: $CAPACITY%\nNo longer in critical state" "normal" "$ICON_CHARGING" 4000
            echo "CHARGING" > "$STATE_FILE"
        
        # Periodic status updates for very low battery
        elif [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le 5 ] && [ "$LAST_STATE" == "CRITICAL" ]; then
            show_notification "🚨 EXTREMELY LOW BATTERY!\nOnly $CAPACITY% remaining!\nSYSTEM MAY SHUTDOWN SOON!" "critical" "$ICON_CRITICAL" 0
        fi
    else
        # No battery found notification (only once)
        if [ "$LAST_STATE" != "NO_BATTERY" ]; then
            show_notification "❌ No battery detected\nRunning on AC power only" "normal" "battery-missing" 5000
            echo "NO_BATTERY" > "$STATE_FILE"
        fi
    fi

    sleep 1 # Check every 60 seconds
done
