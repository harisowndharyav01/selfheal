#!/bin/sh

name="connectivity_test"
pidfile="/var/run/${name}.pid"
LOGFILE="/var/log/connectivity.log"
SELFHEAL_LOG="/cfg/selfheal.log"
PING_COUNT=3
PING_TIMEOUT=5

get_ipv4_server() {
    ubus-cli X_TINNO_Selfheal.IPv4PingServer? 2>/dev/null | awk -F= '{print $2}'
}

get_ipv6_server() {
    ubus-cli X_TINNO_Selfheal.IPv6PingServer? 2>/dev/null | awk -F= '{print $2}'
}

get_max_reboot_in_24hr() {
    ubus-cli X_TINNO_Selfheal.PingTestRebootCountIn24Hr? 2>/dev/null | awk -F= '{print $2}'
}

get_pingTest_reboot_count() {
    ubus-cli X_TINNO_Selfheal.PingTestRebootCount? | grep -o '[0-9]*'
}

get_interval() {
    ubus-cli X_TINNO_Selfheal.PingTestInterval? 2>/dev/null | awk -F= '{print $2}'
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

    ubus call X_TINNO_Selfheal increment_pingTest_reboot_count '{}'
}

check_connectivity() {
    while true; do
        : > "$LOGFILE"
        echo "Starting connectivity check at $(date)" >> "$LOGFILE"

        INTERVAL=$(get_interval)
        [ -z "$INTERVAL" ] && INTERVAL=300

        IPv4_PING_SERVER=$(get_ipv4_server)
        IPv6_PING_SERVER=$(get_ipv6_server)

        [ -z "$IPv4_PING_SERVER" ] && IPv4_PING_SERVER="8.8.8.8"
        [ -z "$IPv6_PING_SERVER" ] && IPv6_PING_SERVER="2001:4860:4860::8888"

        echo "Using IPv4 Ping Server: $IPv4_PING_SERVER" >> "$LOGFILE"
        echo "Using IPv6 Ping Server: $IPv6_PING_SERVER" >> "$LOGFILE"
        echo "Ping binary path: $(which ping)" >> "$LOGFILE"
        echo "Ping6 binary path: $(which ping6)" >> "$LOGFILE"

        # Wait for default route
        echo "Checking for default route..." >> "$LOGFILE"
        while ! ip route | grep -q default; do
            echo "Waiting for default route..." >> "$LOGFILE"
            sleep 1
        done

        echo "Default route is available." >> "$LOGFILE"
        echo "Current interface state:" >> "$LOGFILE"
        ip addr >> "$LOGFILE"
        ip route >> "$LOGFILE"

        IPv4_OK=0
        IPv6_OK=0

        echo "Pinging IPv4 server..." >> "$LOGFILE"
        ping -c $PING_COUNT -W $PING_TIMEOUT "$IPv4_PING_SERVER" >> "$LOGFILE" 2>&1 && {
            echo "IPv4 ping SUCCESS" >> "$LOGFILE"
            IPv4_OK=1
        } || {
            echo "IPv4 ping FAILED" >> "$LOGFILE"
        }

        echo "Pinging IPv6 server..." >> "$LOGFILE"
        ping6 -c $PING_COUNT -W $PING_TIMEOUT "$IPv6_PING_SERVER" >> "$LOGFILE" 2>&1 && {
            echo "IPv6 ping SUCCESS" >> "$LOGFILE"
            IPv6_OK=1
        } || {
            echo "IPv6 ping FAILED" >> "$LOGFILE"
        }

        REBOOT_LIMIT=$(get_max_reboot_in_24hr)
        REBOOT_COUNT=$(get_pingTest_reboot_count)

        # Only IPv4 check for now
        if [ "$IPv4_OK" -eq 0 ]; then
            if [ "$REBOOT_COUNT" -lt "$REBOOT_LIMIT" ]; then
                REASON="Connectivity Test Failed (IPv4: $IPv4_PING_SERVER)"
                echo "$REASON" >> "$LOGFILE"
                REASON="Connectivity Test Failed"
                log_reboot_event "$REASON"
                sync
                reboot
                exit 0
            else
                echo "Reboot limit reached: $REBOOT_COUNT reboots in the last 24 hours" >> "$LOGFILE"
            fi
        else
            echo "Connectivity OK - No reboot needed" >> "$LOGFILE"
        fi

        echo "Connectivity check completed at $(date)" >> "$LOGFILE"
        echo "----------------------------------------" >> "$LOGFILE"
        sleep "$INTERVAL"
    done
}

case $1 in
    start|boot)
        check_connectivity &
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
