-include_lib("kernel/include/inet.hrl").
-include_lib("kernel/include/file.hrl").
-include("../supercast/include/supercast.hrl").
-include("../errd/include/errd.hrl").
-include("../esnmp/include/esnmp.hrl").

% for info: syslog like security levels
-define(EMERGENCY,  0).
-define(ALERT,      1).
-define(CRITICAL,   2).
-define(ERROR,      3).
-define(WARNING,    4).
-define(NOTICE,     5).
-define(INFO,       6).
-define(DEBUG,      7).

-type hostname()                :: undefined | inet:hostname().
-type ip_add()                  :: undefined | inet:ip_address().
-type probe_id()                :: undefined | integer().
-type probe_type()              :: undefined | fetch | status | set_property.
-type property_key()            :: any().
-type property_val()            :: any().
-type role()                    :: string().
-type seconds()                 :: integer().
-type property()                :: {atom(),any()}.
-type tag()                     :: any().
-type target_id()               :: atom().
-type tfun()                    :: fun() | undefined.
-type timeout_alert()           :: fun() | undefined.
-type timeout_threshold()       :: integer() | undefined.
-type oid()                     :: [byte()].
-type nagios_flag()             :: string().
-type nagios_arg()              :: {nagios_flag(), string() | tuple()}.

-record(inspector, {
    module,
    conf
}).

-record(logger, {
    module,
    conf
}).

% NAGIOS btracker_probe_nagios_compat
-record(nagios_perf_data, {
    label       = undefined     :: string(),
    value       = undefined     :: integer(),
    uom         = undefined     :: string(),
    warn        = undefined     :: integer(),
    crit        = undefined     :: integer(),
    min         = undefined     :: integer(),
    max         = undefined     :: integer()
}).

-record(nagios_plugin_return, {
    text_out        = undefined     :: string(),
    perfs           = undefined     :: [#nagios_perf_data{}],
    original_output = undefined     :: string(),
    timestamp       = undefined     :: integer()
}).

-record(tracker_probe_return, {
    value           = undefined,
    timestamp       = undefined     :: integer()
}).

-record(nagios_plugin, {
    executable  = undefined             :: string(),
    args        = []                    :: [nagios_arg()]
}).

-record(rrd_def, {
    rrd_create          = ""            :: #rrd_create{},
    rrd_update          = ""            :: #rrd_ds_update{},
    rrd_graph           = ""            :: string()
}).


-record(probe, {
    id                  = undefined     :: probe_id(), % unique in a target
    pid                 = undefined     :: undefined | pid(),
    name                = undefined     :: string(),
    permissions         = #perm_conf{}  :: #perm_conf{},
    tracker_probe_mod   = undefined     :: undefined | module(),
    tracker_probe_conf  = undefined     :: any(),
    status              = 'UNKNOWN'     :: 'UNKNOWN' | atom(),
    timeout             = 5             :: integer(),
    step                = 60            :: integer(),
    type                = undefined     :: fetch|status|{property, atom()},
    inspectors          = []            :: [#inspector{}],
    loggers             = []            :: [#logger{}],

    active              = 1             :: 1 | 0,
    % if it is a snmp probe this fild must exist
    snmp_oids           = []            :: [oid()]
}).

-record(target, {
    id          = undefined     :: target_id(),
    global_perm = #perm_conf{
        read        =   ["admin"],
        write       =   ["admin"]
    },
    properties  = [
        {ip,            undefined},
        {hostname,      undefined},
        {sysname,       undefined},
        {snmp_conf,     undefined}
    ]        :: [property()],
    probes      = [] :: [#probe{}],
    directory   = ""
}).

-record(probe_server_state, {
    target,
    probe,
    inspectors_state    = [],
    loggers_state       = []
}).
