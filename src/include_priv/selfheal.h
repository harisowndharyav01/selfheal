#if !defined(__SELFHEAL_H__)
#define __SELFHEAL_H__

#ifdef __cplusplus
extern "C"
{
#endif

#include <amxrt/amxrt.h>
#include <amxd/amxd_object.h>
#include <amxd/amxd_object_event.h>
#include <amxd/amxd_transaction.h>
#include <amxd/amxd_action.h>
#include <amxo/amxo_save.h>
#include <amxc/amxc.h>
#include <amxc/amxc_macros.h>
#include <amxp/amxp.h>
#include <amxd/amxd_dm.h>
#include <amxb/amxb.h>
#include <amxo/amxo.h>
#include <amxp/amxp_timer.h>
#include <amxd/amxd_parameter.h>
#include <amxd/amxd_path.h>
#include <amxd/amxd_function.h>
#include <amxd/amxd_object_function.h>

// Entry point
int _selfheal_main(int reason, amxd_dm_t* dm, amxo_parser_t* parser);

void _increment_cpu_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv);
void _increment_memory_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv);
void _increment_resource_monitor_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv);
void _increment_pingTest_reboot_count(UNUSED const amxc_var_t* data, UNUSED void* priv);

void _add_reboot_entry(const char* reason);

amxd_status_t _selfheal_is_valid_ipv4(amxd_object_t* object,
                                     amxd_param_t* param,
                                     amxd_action_t reason,
                                     const amxc_var_t* const args,
                                     amxc_var_t* retval,
                                     void* priv);

amxd_status_t _selfheal_is_valid_ipv6(amxd_object_t* object,
                                     amxd_param_t* param,
                                     amxd_action_t reason,
                                     const amxc_var_t* const args,
                                     amxc_var_t* retval,
                                     void* priv);

// Accessors
amxd_dm_t* selfheal_get_dm(void);
amxo_parser_t* selfheal_get_parser(void);
amxc_var_t* selfheal_get_config(void);

// Handlers
void _set_status(const char* sig_name, const amxc_var_t* data, void* priv);

#ifdef __cplusplus
}
#endif

#endif // __SELFHEAL_H__

