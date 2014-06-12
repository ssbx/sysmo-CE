% This file is part of "Enms" (http://sourceforge.net/projects/enms/)
% Copyright (C) 2012 <Sébastien Serre sserre.bx@gmail.com>
% 
% Enms is a Network Management System aimed to manage and monitor SNMP
% targets, monitor network hosts and services, provide a consistent
% documentation system and tools to help network professionals
% to have a wide perspective of the networks they manage.
% 
% Enms is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% Enms is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with Enms.  If not, see <http://www.gnu.org/licenses/>.
-module(bmonitor_probe_snmp).
-behaviour(beha_monitor_probe).
-include_lib("snmp/include/snmp_types.hrl").
-include("include/monitor.hrl").

%% beha_monitor_probe exports
-export([
    init/2,
    exec/1,
    info/0
]).

-record(state, {
    agent,
    oids,
    request_oids,
    timeout,
    method
}).

info() -> {ok, "snmp get and walk module"}.

init(Target, Probe) ->

    TargetName  = Target#target.id,
    AgentName   = atom_to_list(TargetName),

    TargetIp    = Target#target.ip,
    {ok, Ip}    = inet:parse_address(TargetIp),

    Conf        = Probe#probe.monitor_probe_conf,
    Port        = Conf#snmp_conf.port,
    Version     = Conf#snmp_conf.version,
    Community   = Conf#snmp_conf.community,
    Oids        = Conf#snmp_conf.oids,
    Method      = Conf#snmp_conf.method,

    case snmp_manager:agent_registered(AgentName) of
        true  -> ok;
        false ->
            SnmpArgs = [
                {engine_id, "none"},
                {address,   Ip},
                {port  ,    Port},
                {version,   Version},
                {community, Community}
            ],
            snmp_manager:register_agent(AgentName, SnmpArgs)
    end,

    {ok, #state{
            agent           = AgentName,
            oids            = Oids,
            request_oids    = [Oid || {_, Oid} <- Oids],
            timeout         = Probe#probe.timeout * 1000,
            method          = Method
        }
    }.

exec(State) ->

    Agent           = State#state.agent,
    Request         = State#state.request_oids,
    Oids            = State#state.oids,
    Timeout         = State#state.timeout,
    Method          = State#state.method,

    {_, MicroSec1}  = sys_timestamp(),
    % TODO use snmp_manager:bulk_walk
    case Method of
        get ->
            Reply   = snmp_manager:sync_get(Agent, Request, Timeout);
        {walk, WOids} ->
            ReplyT   = [
                snmp_manager:sync_walk_bulk(Agent, Oid) ||
                    Oid <- WOids],
            Reply = {ok, lists:flatten(ReplyT)}
    end,

    {_, MicroSec2}  = sys_timestamp(),

    case Reply of
        {error, _Error} = R ->
            error_logger:info_msg("snmp fail ~p ~p ~p", [?MODULE, ?LINE, R]),
            KV = [{"status",'CRITICAL'},{"sys_latency",MicroSec2 - MicroSec1}],
            OR = to_string(R),
            S  = 'CRITICAL',
            PR = #probe_return{
                status          = S,
                original_reply  = OR,
                key_vals        = KV,
                timestamp       = MicroSec2},
            {ok, State, PR};
        {ok, SnmpReply, _Remaining} ->
            PR      = eval_snmp_get_return(SnmpReply, Oids),
            KV      = PR#probe_return.key_vals,
            KV2     = [{"sys_latency", MicroSec2 - MicroSec1} | KV],
            PR2     = PR#probe_return{
                timestamp = MicroSec2,
                key_vals  = KV2},
            {ok, State, PR2};
        {ok, SnmpReply} ->
            PR      = eval_snmp_walk_return(SnmpReply, Oids),
            KV      = PR#probe_return.key_vals,
            KV2     = [{"sys_latency", MicroSec2 - MicroSec1} | KV],
            PR2     = PR#probe_return{
                timestamp = MicroSec2,
                key_vals  = KV2},
            {ok, State, PR2}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% UTILS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @private
eval_snmp_get_return({noError, _, VarBinds}, Oids) ->
    eval_snmp_return(VarBinds, Oids).

eval_snmp_walk_return(VarBinds, Oids) ->
    OidsN = [{K, lists:droplast(O)} || {K, O} <- Oids],
    eval_snmp_return(VarBinds, OidsN).

eval_snmp_return(VarBinds, Oids) ->
    FilteredVarBinds = filter_varbinds(VarBinds),
    KeyVals = [
        {Key, (lists:keyfind(Oid, 2, FilteredVarBinds))#varbind.value} || 
        {Key, Oid} <- Oids
    ],
    #probe_return{
        status          = 'OK',
        original_reply  = to_string(VarBinds),
        key_vals        = [{"status", 'OK'} | KeyVals]
    }.

filter_varbinds(VarBinds) ->
    lists:filter(
    fun(X) ->
        case X of
            {varbind, _, _, _, _} -> true;
            _ -> 
                error_logger:info_msg("~p ~p Unknown varbind: ~p~n",
                    [?MODULE, ?LINE, X]),
                false
        end
    end, VarBinds).

to_string(Term) ->
    lists:flatten(io_lib:format("~p~n", [Term])).

sys_timestamp() ->
    {Meg, Sec, Micro} = os:timestamp(),
    Seconds      = Meg      * 1000000 + Sec,
    Microseconds = Seconds  * 1000000 + Micro,
    {Seconds, Microseconds}.
