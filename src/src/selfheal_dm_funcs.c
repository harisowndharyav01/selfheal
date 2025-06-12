#include <debug/sahtrace.h>
#include <debug/sahtrace_macros.h>

#include <amxc/amxc.h>
#include <amxp/amxp_signal.h>
#include <amxd/amxd_dm.h>
#include <amxd/amxd_object.h>
#include <amxd/amxd_action.h>
#include <amxd/amxd_transaction.h>
#include <amxc/amxc_variant.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <amxc/amxc_macros.h>
#include <amxd/amxd_function.h>

#include <string.h>
#include <time.h>
#include <stdlib.h>

#include "selfheal.h"

#define ERROR_INVALID_VALUE -1
#define ERROR_NOT_FOUND     -2
#define ME "selfheal"



void _set_status(UNUSED const char* sig_name, const amxc_var_t* data, UNUSED void* priv) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* obj = amxd_dm_signal_get_object(dm, data);
    const amxc_var_t* enable_val = amxd_object_get_param_value(obj, "Enable");

    if (enable_val != NULL) {
        bool enabled = amxc_var_dyncast(bool, enable_val);
        amxd_trans_t trans;
        amxd_trans_init(&trans);
        amxd_trans_set_attr(&trans, amxd_tattr_change_ro, true);
        amxd_trans_select_object(&trans, obj);

        if (enabled) {
            amxd_trans_set_value(cstring_t, &trans, "Status", "Enabled");
            SAH_TRACEZ_INFO(ME, "Selfheal enabled, setting status to Enabled");

            // Start selfheal process
            SAH_TRACEZ_INFO(ME, "Starting memory_monitor process");
            int ret = system("/etc/init.d/memory_monitor start");
            if (ret != 0) {
                SAH_TRACEZ_WARNING(ME, "Failed to start memory_monitor process. Return code: %d", ret);
            }
            SAH_TRACEZ_INFO(ME, "Starting cpu_monitor process");
            ret = system("/etc/init.d/cpu_monitor start");
            if (ret != 0) {
                SAH_TRACEZ_WARNING(ME, "Failed to start cpu_monitor process. Return code: %d", ret);
            }
            SAH_TRACEZ_INFO(ME, "Starting connectivity_test process");
            ret = system("/etc/init.d/connectivity_test start");
            if (ret != 0) {
                SAH_TRACEZ_WARNING(ME, "Failed to start connectivity_test process. Return code: %d", ret);
            }
        } else {
            amxd_trans_set_value(cstring_t, &trans, "Status", "Disabled");
            SAH_TRACEZ_INFO(ME, "Selfheal disabled, setting status to Disabled");

            // Kill related processes
            SAH_TRACEZ_INFO(ME, "Killing cpu_monitor, and memory_monitor processes");
            system("killall cpu_monitor");
            system("killall memory_monitor");

            SAH_TRACEZ_INFO(ME, "Killing connectivity_test process");
            system("killall connectivity_test");
        }

        amxd_trans_apply(&trans, dm);
        amxd_trans_clean(&trans);
    }

    SAH_TRACEZ_OUT(ME);
}

void _increment_cpu_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* obj = amxd_dm_get_object(dm, "X_TINNO_Selfheal");
    if (obj == NULL) {
        SAH_TRACEZ_ERROR(ME, "Selfheal object not found");
        SAH_TRACEZ_OUT(ME);
        return;
    }

    const amxc_var_t* count_val = amxd_object_get_param_value(obj, "CpuRebootCount");
    uint32_t current_count = amxc_var_dyncast(uint32_t, count_val);

    amxd_trans_t trans;
    amxd_trans_init(&trans);
    amxd_trans_set_attr(&trans, amxd_tattr_change_ro, true);
    amxd_trans_select_object(&trans, obj);

    amxd_trans_set_value(uint32_t, &trans, "CpuRebootCount", current_count + 1);
    SAH_TRACEZ_INFO(ME, "Incrementing CpuRebootCount to %u", current_count + 1);

    amxd_trans_apply(&trans, dm);
    amxd_trans_clean(&trans);

    SAH_TRACEZ_OUT(ME);
}

void _increment_memory_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* obj = amxd_dm_get_object(dm, "X_TINNO_Selfheal");
    if (obj == NULL) {
        SAH_TRACEZ_ERROR(ME, "Selfheal object not found");
        SAH_TRACEZ_OUT(ME);
        return;
    }

    const amxc_var_t* count_val = amxd_object_get_param_value(obj, "MemoryRebootCount");
    uint32_t current_count = amxc_var_dyncast(uint32_t, count_val);

    amxd_trans_t trans;
    amxd_trans_init(&trans);
    amxd_trans_set_attr(&trans, amxd_tattr_change_ro, true);
    amxd_trans_select_object(&trans, obj);

    amxd_trans_set_value(uint32_t, &trans, "MemoryRebootCount", current_count + 1);
    SAH_TRACEZ_INFO(ME, "Incrementing MemoryRebootCount to %u", current_count + 1);

    amxd_trans_apply(&trans, dm);
    amxd_trans_clean(&trans);

    SAH_TRACEZ_OUT(ME);
}

void _increment_resource_monitor_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* obj = amxd_dm_get_object(dm, "X_TINNO_Selfheal");
    if (obj == NULL) {
        SAH_TRACEZ_ERROR(ME, "Selfheal object not found");
        SAH_TRACEZ_OUT(ME);
        return;
    }

    const amxc_var_t* count_val = amxd_object_get_param_value(obj, "ResourceMonitorRebootCount");
    uint32_t current_count = amxc_var_dyncast(uint32_t, count_val);

    amxd_trans_t trans;
    amxd_trans_init(&trans);
    amxd_trans_set_attr(&trans, amxd_tattr_change_ro, true);
    amxd_trans_select_object(&trans, obj);

    amxd_trans_set_value(uint32_t, &trans, "ResourceMonitorRebootCount", current_count + 1);
    SAH_TRACEZ_INFO(ME, "Incrementing ResourceMonitorRebootCount to %u", current_count + 1);

    amxd_trans_apply(&trans, dm);
    amxd_trans_clean(&trans);

    SAH_TRACEZ_OUT(ME);
}

void _increment_pingTest_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* obj = amxd_dm_get_object(dm, "X_TINNO_Selfheal");
    if (obj == NULL) {
        SAH_TRACEZ_ERROR(ME, "Selfheal object not found");
        SAH_TRACEZ_OUT(ME);
        return;
    }

    const amxc_var_t* count_val = amxd_object_get_param_value(obj, "PingTestRebootCount");
    uint32_t current_count = amxc_var_dyncast(uint32_t, count_val);

    amxd_trans_t trans;
    amxd_trans_init(&trans);
    amxd_trans_set_attr(&trans, amxd_tattr_change_ro, true);
    amxd_trans_select_object(&trans, obj);

    amxd_trans_set_value(uint32_t, &trans, "PingTestRebootCount", current_count + 1);
    SAH_TRACEZ_INFO(ME, "Incrementing PingTestRebootCount to %u", current_count + 1);

    amxd_trans_apply(&trans, dm);
    amxd_trans_clean(&trans);

    SAH_TRACEZ_OUT(ME);
}

void _add_reboot_entry(const char* reason) {
    SAH_TRACEZ_IN(ME);

    amxd_dm_t* dm = selfheal_get_dm();
    amxd_object_t* parent = amxd_dm_get_object(dm, "X_TINNO_Selfheal");
    if (parent == NULL) {
        SAH_TRACEZ_ERROR(ME, "Selfheal object not found");
        SAH_TRACEZ_OUT(ME);
        return;
    }

    // Format current time as ISO8601
    char time_buf[32];
    time_t now = time(NULL);
    struct tm* tm_info = gmtime(&now);
    strftime(time_buf, sizeof(time_buf), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    amxd_trans_t trans;
    amxd_trans_init(&trans);
    amxd_trans_select_object(&trans, parent);

    amxd_path_t inst_path;
    amxd_path_init(&inst_path, "/Device.X_TINNO_Selfheal.Reboot");
    uint32_t index = 0;
    amxd_trans_add_inst(&trans, index, "/Device.X_TINNO_Selfheal.Reboot");

    char param_path[128];
    amxc_var_t var;

    // Set Time
    snprintf(param_path, sizeof(param_path), "Reboot.{%s}.Time", time_buf);
    amxc_var_set_cstring_t(&var, time_buf);
    amxd_trans_set_param(&trans, param_path, &var);

    // Set Reason
    snprintf(param_path, sizeof(param_path), "Reboot.{%s}.Reason", time_buf);
    amxc_var_set_cstring_t(&var, reason);
    amxd_trans_set_param(&trans, param_path, &var);

    // Apply the transaction
    if (amxd_trans_apply(&trans, dm) != 0) {
        SAH_TRACEZ_ERROR(ME, "Failed to apply transaction");
    }

    amxd_trans_clean(&trans);

    SAH_TRACEZ_INFO(ME, "Added reboot entry at time %s with reason: %s", time_buf, reason);
    SAH_TRACEZ_OUT(ME);
}

amxd_status_t _selfheal_is_valid_ipv4(UNUSED amxd_object_t* object,
                                      UNUSED amxd_param_t* param,
                                      amxd_action_t reason,
                                      const amxc_var_t* const args,
                                      UNUSED amxc_var_t* const retval,
                                      UNUSED void* priv) {
    SAH_TRACEZ_IN("selfheal");

    amxd_status_t status = amxd_status_invalid_arg;

    if (reason != action_param_validate) {
        SAH_TRACEZ_WARNING("selfheal", "Called with unsupported action: %d", reason);
        return amxd_status_function_not_implemented;
    }

    const char* ip_str = GET_CHAR(args, NULL);
    if (ip_str == NULL || strlen(ip_str) == 0) {
        return amxd_status_ok;
    }

    struct sockaddr_in sa;
    if (inet_pton(AF_INET, ip_str, &(sa.sin_addr)) == 1) {
        status = amxd_status_ok;
    } else {
        SAH_TRACEZ_WARNING("selfheal", "Invalid IPv4 address: %s", ip_str);
    }

    SAH_TRACEZ_OUT("selfheal");
    return status;
}

amxd_status_t _selfheal_is_valid_ipv6(UNUSED amxd_object_t* object,
                                      UNUSED amxd_param_t* param,
                                      amxd_action_t reason,
                                      const amxc_var_t* const args,
                                      UNUSED amxc_var_t* const retval,
                                      UNUSED void* priv) {

    SAH_TRACEZ_IN("selfheal");
    amxd_status_t status = amxd_status_invalid_arg;

    if (reason != action_param_validate) {
        SAH_TRACEZ_WARNING("selfheal", "Called with unsupported action: %d", reason);
        return amxd_status_function_not_implemented;
    }

    const char* ip_str = GET_CHAR(args, NULL);
    if (ip_str == NULL || strlen(ip_str) == 0) {
        return amxd_status_ok;
    }

    struct sockaddr_in6 sa6;
    if (inet_pton(AF_INET6, ip_str, &(sa6.sin6_addr)) == 1) {
        status = amxd_status_ok;
    } else {
        SAH_TRACEZ_WARNING("selfheal", "Invalid IPv6 address: %s", ip_str);
    }
    SAH_TRACEZ_OUT("selfheal");
    return status;
}

