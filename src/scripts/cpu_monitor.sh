#!/bin/sh

name="cpu_monitor"
pidfile="/var/run/${name}.pid"
LOGFILE="/var/log/cpu_monitor.log"
SELFHEAL_LOG="/cfg/selfheal.log"

get_cpu_threshold() {
    ubus-cli X_TINNO_Selfheal.AvgCPUThreshold? 2>/dev/null | awk -F= '{print $2}'
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

    timestamp=$(date '+%d-%b-%Y;%H:%M:%S')
    entry="$timestamp---$reason"

    # Append entry
    echo "$entry" >> "$SELFHEAL_LOG"

    # Trim to last 30 lines
    tail -n 30 "$SELFHEAL_LOG" > "${SELFHEAL_LOG}.tmp"
    mv "${SELFHEAL_LOG}.tmp" "$SELFHEAL_LOG"

    update_reboot_entries "$reason"

    ubus call X_TINNO_Selfheal increment_cpu_reboot_count '{}'
    ubus call X_TINNO_Selfheal increment_resource_monitor_reboot_count '{}'

}

get_avg_cpu_usage() {
    usage1=$(top -b -n1 | grep "CPU:" | awk '{for(i=1;i<=NF;i++) if($i=="idle") { gsub("%", "", $(i-1)); print 100 - $(i-1) }}')
    sleep 10
    usage2=$(top -b -n1 | grep "CPU:" | awk '{for(i=1;i<=NF;i++) if($i=="idle") { gsub("%", "", $(i-1)); print 100 - $(i-1) }}')
    sleep 10
    usage3=$(top -b -n1 | grep "CPU:" | awk '{for(i=1;i<=NF;i++) if($i=="idle") { gsub("%", "", $(i-1)); print 100 - $(i-1) }}')
    sleep 10
    usage4=$(top -b -n1 | grep "CPU:" | awk '{for(i=1;i<=NF;i++) if($i=="idle") { gsub("%", "", $(i-1)); print 100 - $(i-1) }}')
    usage=$(( (usage1 + usage2 + usage3 + usage4) / 4 ))
    echo "${usage}"
}

get_cpu_reboot_count() {
    ubus-cli X_TINNO_Selfheal.CpuRebootCount? | grep -o '[0-9]*'
}

monitor_cpu() {
    sleep 60
    while true; do
        : > "$LOGFILE"

        echo "==============================" >> "$LOGFILE"
        echo "CPU Monitor Log - $(date)" >> "$LOGFILE"
        echo "==============================" >> "$LOGFILE"

        THRESHOLD=$(get_cpu_threshold)
        INTERVAL=$(get_interval)
        REBOOT_LIMIT=$(get_max_reboot_in_24hr)

        [ -z "$THRESHOLD" ] && THRESHOLD=80
        [ -z "$INTERVAL" ] && INTERVAL=300

        echo "Configured CPU Threshold: ${THRESHOLD}%" >> "$LOGFILE"
        echo "Monitoring Interval: ${INTERVAL} seconds" >> "$LOGFILE"

        USAGE=$(get_avg_cpu_usage)
        REBOOT_COUNT=$(get_cpu_reboot_count)

        echo "Average CPU Usage: ${USAGE}%" >> "$LOGFILE"

        if [ "$USAGE" -ge "$THRESHOLD" ]; then
            if [ "$REBOOT_COUNT" -ge "$REBOOT_LIMIT" ]; then
                echo "Reboot skipped: CPU reboot count ($REBOOT_COUNT) has reached the limit ($REBOOT_LIMIT)." >> "$LOGFILE"
            else
                reason="High CPU Usage Detected: ${USAGE}% used"
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
        monitor_cpu &
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
