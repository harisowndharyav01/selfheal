#!/bin/sh

name="selfheal"
pidfile="/var/run/selfheal.pid"

case $1 in
    start|boot)
        MAX_RETRIES=10
        RETRY_INTERVAL=10
        PING_TARGET="8.8.8.8"

        ${name} -D /etc/amx/selfheal/selfheal.odl &
        echo $! > "$pidfile"

        sleep 10

        is_enabled=$(ubus-cli X_TINNO_Selfheal.Enable? 2>/dev/null | awk -F= '{print $2}' | xargs)
        echo "[DEBUG] is_enabled = '$is_enabled'"

        if [ "$is_enabled" != "1" ]; then
                echo "Self-heal is disabled or ubus value invalid. Exiting."
                exit 0
        else
                echo "Self-heal is enabled. Continuing."
        fi

        for i in $(seq 1 $MAX_RETRIES); do
            if ping -c 1 -W 2 "$PING_TARGET" >/dev/null 2>&1; then
                echo "Internet connectivity verified."

                sleep 20

                /etc/init.d/memory_monitor start &
                /etc/init.d/cpu_monitor start &
                #/etc/init.d/connectivity_test start &
                /etc/init.d/thermal_monitor.sh start &
                break
            fi
            echo "Ping failed. Retrying in $RETRY_INTERVAL seconds..."
            sleep "$RETRY_INTERVAL"
        done

        ;;
    stop)
        /etc/init.d/memory_monitor stop &
        /etc/init.d/cpu_monitor stop &
        #/etc/init.d/connectivity_test stop &
        /etc/init.d/thermal_monitor.sh stop &
        if [ -f "$pidfile" ]; then
            kill -9 "$(cat $pidfile)"
            rm -f "$pidfile"
        else
            echo "No PID file found. Is $name running?"
        fi
        ;;
    restart)
        $0 stop
        $0 start
        ;;
    *)
        echo "Usage: $0 [start|boot|stop|restart]"
        ;;
esac
