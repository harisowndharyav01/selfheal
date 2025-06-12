#!/bin/sh

name="thermal_monitor"
pidfile="/var/run/${name}.pid"
LOGFILE="/var/log/thermal_monitor.log"
SELFHEAL_LOG="/cfg/selfheal.log"

get_threshold() {
    ubus-cli X_TINNO_Selfheal.AvgTemperatureThreshold? 2>/dev/null | awk -F= '{print $2}'
}

get_interval() {
    ubus-cli X_TINNO_Selfheal.TemperatureMonitorInterval? 2>/dev/null | awk -F= '{print $2}'
}


update_reboot_entries() {
    MAX_ENTRIES=10
    REASON="$1"
    TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Get current number of entries
    ENTRY_COUNT=$(ubus call X_TINNO_Selfheal _get '{ "rel_path": "", "parameters": ["RebootNumberOfEntries"] }' | grep -o '"RebootNumberOfEntries": [0-9]*' | grep -o '[0-9]*')

    # If fewer than MAX_ENTRIES, just add
    if [ "$ENTRY_COUNT" -lt "$MAX_ENTRIES" ]; then
        ubus call X_TINNO_Selfheal _add "{
            \"rel_path\": \"Reboot\",
            \"parameters\": {
                \"Time\": \"$TIME\",
                \"Reason\": \"$REASON\"
            }
        }"
        return
    fi

    # Shift existing entries 2->1, 3->2, ..., 10->9
    for i in $(seq 1 $((MAX_ENTRIES - 1))); do
        NEXT=$((i + 1))
        REASON_VAL=$(ubus-cli X_TINNO_Selfheal.Reboot.$NEXT.Reason? 2>/dev/null | sed -n 's/^.*Reason="\([^"]*\)".*/\1/p')
        TIME_VAL=$(ubus-cli X_TINNO_Selfheal.Reboot.$NEXT.Time? 2>/dev/null | sed -n 's/^.*Time="\([^"]*\)".*/\1/p')

        ubus call X_TINNO_Selfheal _set "{
            \"rel_path\": \"Reboot.$i\",
            \"parameters\": {
                \"Reason\": \"$REASON_VAL\",
                \"Time\": \"$TIME_VAL\"
            }
        }"
    done

    # Add new entry at index 10
    ubus call X_TINNO_Selfheal _set "{
        \"rel_path\": \"Reboot.$MAX_ENTRIES\",
        \"parameters\": {
            \"Reason\": \"$REASON\",
            \"Time\": \"$TIME\"
        }
    }"
}

log_reboot_event() {
    reason="$1"

    timestamp=$(date '+%d-%b-%Y;%H:%M:%S')
    entry="$timestamp---$reason"

    # Append entry
    echo "$entry" >> "$SELFHEAL_LOG"

    # Trim to last 30 lines
    tail -n 30 "$SELFHEAL_LOG" > "${SELFHEAL_LOG}.tmp"
    mv "${SELFHEAL_LOG}.tmp" "$SELFHEAL_LOG"
    
    update_reboot_entries "$reason"
    
    ubus call X_TINNO_Selfheal increment_temperature_reboot_count '{}'

}

monitor_thermal() {
    while true; do
        : > "$LOGFILE"

        echo "==============================" >> "$LOGFILE"
        echo "Thermal Monitor Log - $(date)" >> "$LOGFILE"
        echo "==============================" >> "$LOGFILE"

        THRESHOLD=$(get_threshold)
        INTERVAL=$(get_interval)

        [ -z "$THRESHOLD" ] && THRESHOLD=80
        [ -z "$INTERVAL" ] && INTERVAL=300

        echo "Configured Temperature Threshold: ${THRESHOLD}°C" >> "$LOGFILE"
        echo "Monitoring Interval: ${INTERVAL} seconds" >> "$LOGFILE"

        for zone in /sys/class/thermal/thermal_zone*/temp; do
            zone_id=$(basename "$(dirname "$zone")")
            temp_mC=$(cat "$zone")
            temp_C=$((temp_mC / 1000))

            echo "$zone_id: ${temp_C}°C" >> "$LOGFILE"

            if [ "$temp_C" -ge "$THRESHOLD" ]; then
                reason="Over Temperature Detected - $zone_id at ${temp_C}°C"
                log_reboot_event "$reason"

                sync
                reboot
                exit 0
            fi
        done

        echo "------------------------------------" >> "$LOGFILE"
        sleep "$INTERVAL"
    done
}

case $1 in
    start|boot)
        monitor_thermal &
        echo $! > "$pidfile"
        ;;
    stop)
        [ -f "$pidfile" ] && kill -9 "$(cat "$pidfile")" && rm -f "$pidfile"
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    *)
        echo "Usage: $0 [start|boot|stop|restart]"
        ;;
esac
