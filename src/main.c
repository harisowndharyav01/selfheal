#include <debug/sahtrace.h>
#include "selfheal.h"

#define ME "selfheal"

static struct {
    amxd_dm_t* dm;
    amxo_parser_t* parser;
}selfheal_ctx;

static int selfheal_init(amxd_dm_t* dm, amxo_parser_t* parser) {
    selfheal_ctx.dm = dm;
    selfheal_ctx.parser = parser;
    SAH_TRACEZ_INFO(ME, "Selfheal component initialized");
    return 0;
}


static int selfheal_cleanup(UNUSED amxd_dm_t* dm, UNUSED amxo_parser_t* parser) {
    selfheal_ctx.dm = NULL;
    selfheal_ctx.parser = NULL;
    SAH_TRACEZ_INFO(ME, "Selfheal component cleaned up");
    return 0;
}

amxd_dm_t* selfheal_get_dm(void) {
    return selfheal_ctx.dm;
}

amxo_parser_t* selfheal_get_parser(void) {
    return selfheal_ctx.parser;
}

amxc_var_t* selfheal_get_config(void) {
    return &(selfheal_ctx.parser->config);
}

int _selfheal_main(int reason, amxd_dm_t* dm, amxo_parser_t* parser) {
    switch (reason) {
        case AMXO_START: return selfheal_init(dm, parser);
        case AMXO_STOP:  return selfheal_cleanup(dm, parser);
        default:         return 0;
    }
}
