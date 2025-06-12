#!/bin/sh

name="memory_monitor"
pidfile="/var/run/${name}.pid"
LOGFILE="/var/log/memory_monitor.log"
SELFHEAL_LOG="/cfg/selfheal.log"
HISTORY_FILE="/tmp/mem_usage_history"
MAX_HISTORY=5  # Number of entries to track
LEAK_THRESHOLD_INCREMENT=5  # percentage

get_mem_threshold() {
    ubus-cli X_TINNO_Selfheal.AvgMemoryThreshold? 2>/dev/null | awk -F= '{print $2}'
}

get_interval() {
    ubus-cli X_TINNO_Selfheal.ResourceMonitorInterval? 2>/dev/null | awk -F= '{print $2}'
}

get_max_reboot_in_24hr() {
    ubus-cli X_TINNO_Selfheal.ResourceMonitorRebootCountIn24hr? 2>/dev/null | awk -F= '{print $2}'
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
    timestamp=$(date -Iseconds)

    timestamp=$(date '+%d-%b-%Y;%H:%M:%S')
    entry="$timestamp---$reason"

    # Append entry
    echo "$entry" >> "$SELFHEAL_LOG"

    # Trim to last 30 lines
    tail -n 30 "$SELFHEAL_LOG" > "${SELFHEAL_LOG}.tmp"
    mv "${SELFHEAL_LOG}.tmp" "$SELFHEAL_LOG"

    update_reboot_entries "$reason"

    ubus call X_TINNO_Selfheal increment_memory_reboot_count '{}'
    ubus call X_TINNO_Selfheal increment_resource_monitor_reboot_count '{}'

}

get_memory_reboot_count() {
    ubus-cli X_TINNO_Selfheal.MemoryRebootCount? | grep -o '[0-9]*'
}

monitor_memory() {
    sleep 10
    while true; do
        : > "$LOGFILE"

        echo "==============================" >> "$LOGFILE"
        echo "Memory Monitor Log - $(date)" >> "$LOGFILE"
        echo "==============================" >> "$LOGFILE"

        THRESHOLD=$(get_mem_threshold)
        INTERVAL=$(get_interval)
        REBOOT_LIMIT=$(get_max_reboot_in_24hr)

        [ -z "$THRESHOLD" ] && THRESHOLD=80
        [ -z "$INTERVAL" ] && INTERVAL=300

        echo "Configured Memory Threshold: ${THRESHOLD}%" >> "$LOGFILE"
        echo "Monitoring Interval: ${INTERVAL} seconds" >> "$LOGFILE"
        echo "------ Memory Info from /proc/meminfo ------" >> "$LOGFILE"
        grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached" /proc/meminfo >> "$LOGFILE"

        mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

        if [ "$mem_total" -gt 0 ]; then
            used_percent=$(( (100 * (mem_total - mem_available)) / mem_total ))
        else
            used_percent=0
        fi

        echo "Memory Usage: ${used_percent}%" >> "$LOGFILE"

        REBOOT_COUNT=$(get_memory_reboot_count)

        if [ "$used_percent" -ge "$THRESHOLD" ]; then
            if [ "$REBOOT_COUNT" -ge "$REBOOT_LIMIT" ]; then
                echo "Reboot skipped: Memory reboot count ($REBOOT_COUNT) has reached the limit ($REBOOT_LIMIT)." >> "$LOGFILE"
            else
                reason="High Memory Usage Detected: ${used_percent}% used"
                log_reboot_event "$reason"

                sync
                reboot
                exit 0
            fi
        fi

        echo "------------------------------------" >> "$LOGFILE"
        sleep "$INTERVAL"
    done
}

case $1 in
    start|boot)
        monitor_memory &
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
