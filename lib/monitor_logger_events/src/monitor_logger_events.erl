-module(monitor_logger_events).
-include("../monitor/include/monitor.hrl").
-include_lib("stdlib/include/qlc.hrl").
-behaviour(gen_server).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-export([
    start_link/0
]).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    % TODO a single channel for the server status and events
    Rep = mnesia:table_info(schema, tables),
    lists:foreach(fun(X) ->
        insert_cold_start(X)
    end, Rep),
    % read config, some event will not require acknowledgements or/and
    % send notifications.
    {ok, no_state}.

handle_call({init, TableName}, _From, State) ->
    create_table(TableName),
    {reply, ok, State};
handle_call({log, TableName, ProbeReturn}, _From, _S) ->
    {atomic, ProbeEvent} = insert_record(TableName, ProbeReturn),
    Pdu = pdu('probeEventMsg', {TableName, ProbeEvent}),
    {reply, {ok, Pdu}, _S};
handle_call({dump, TargetId, ProbeName}, _F, S) ->
    Pdu = pdu('eventProbeDump', {TargetId, ProbeName}),
    {reply, {ok, Pdu}, S};
handle_call(_R, _F, S) ->
    {noreply, S}.

% 
handle_cast(_,S) ->
    {noreply, S}.

%
handle_info(_, S) ->
    {noreply, S}.

%
terminate(_,_) ->
    ok.

%
code_change(_,S,_) ->
    {ok, S}.

%
% @private
create_table(TableName) ->
    Rep = lists:member(TableName, mnesia:table_info(schema, tables)),
    create_table(TableName, Rep).
create_table(_,         true) -> ok;
create_table(TableName, false) ->
    mnesia:create_table(TableName,
        [
            {access_mode, read_write},
            {attributes, record_info(fields, probe_event)},
            {disc_copies, [node()]},
            {record_name, probe_event},
            {type, set}
        ]
    ).

insert_record(TableName,#probe_return{status = Status, original_reply = String,
            timestamp = Ts}) ->
    F = fun() ->
        Id = mnesia:table_info(TableName, size),
        ProbeEvent = #probe_event{
            id          = Id,
            insert_ts   = Ts,
            status      = Status,
            textual     = String,
            ack_needed  = true
        },
        mnesia:write(TableName, ProbeEvent, write),
        ProbeEvent
    end,
    mnesia:transaction(F).

insert_raw_record(
        TableName, 
        #probe_return{status=Status, original_reply=String, timestamp=Ts},
        AckNeeded
    ) ->
    F = fun() ->
        Id = mnesia:table_info(TableName, size),
        mnesia:write(TableName, 
            #probe_event{
                id          = Id,
                insert_ts   = Ts,
                ack_ts      = 0,
                status      = Status,
                textual     = String,
                ack_needed  = AckNeeded
            }, write
        )
    end,
    mnesia:transaction(F).

insert_cold_start(TableName) ->
    Record = mnesia:table_info(TableName, record_name),
    insert_cold_start(TableName, Record).
insert_cold_start(TableName,    probe_event) ->
    {_, MicroSec} = sys_timestamp(),
    insert_raw_record(TableName, 
        #probe_return{
            status          = 'UNKNOWN', 
            original_reply  = "Server cold start",
            timestamp       = MicroSec}, false);
insert_cold_start(_TableName,   _Record) ->
    ok.

pdu('eventProbeDump', {TargetId, ProbeName}) ->
    F = fun() ->
        Q = qlc:q([E || E <- mnesia:table(ProbeName)]),
        qlc:e(Q)
    end,
    {atomic, Reply} = mnesia:transaction(F),
    ProbeEvents = [
        {'ProbeEvent',atom_to_list(ProbeName),EventId,InsertTs,AckTs,
            atom_to_list(Status),Textual,AckNeeded,AckValue,
                GroupOwner,UserOwner}
        || #probe_event{
            id          = EventId,
            insert_ts   = InsertTs,
            ack_ts      = AckTs,
            status      = Status,
            textual     = Textual,
            ack_needed  = AckNeeded,
            ack_value   = AckValue,
            group_owner = GroupOwner,
            user_owner  = UserOwner}    <- Reply],
    {modMonitorPDU,
        {fromServer,
            {eventProbeDump,
                {'EventProbeDump',
                    atom_to_list(TargetId),
                    atom_to_list(ProbeName),
                    atom_to_list(?MODULE),
                    ProbeEvents}}}};

pdu('probeEventMsg', {ProbeName, #probe_event{
        id          = EventId,
        insert_ts   = InsertTs,
        ack_ts      = AckTs,
        status      = Status,
        textual     = Textual,
        ack_needed  = AckNeeded,
        ack_value   = AckValue,
        group_owner = GroupOwner,
        user_owner  = UserOwner
    }}) ->
    {modMonitorPDU,
        {fromServer,
            {probeEventMsg,
                {'ProbeEvent',
                    atom_to_list(ProbeName),
                    EventId,
                    InsertTs,
                    AckTs,
                    atom_to_list(Status),
                    Textual,
                    AckNeeded,
                    AckValue,
                    GroupOwner,
                    UserOwner}}}}.


sys_timestamp() ->
    {Meg, Sec, Micro} = os:timestamp(),
    Seconds      = Meg * 1000000 + Sec,
    Microseconds = Seconds * 1000000 + Micro,
    {Seconds, Microseconds}.