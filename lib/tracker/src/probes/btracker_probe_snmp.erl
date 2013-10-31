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
-module(btracker_probe_snmp).
-behaviour(beha_tracker_probe).
-behaviour(snmpm_user).
-include_lib("snmp/include/snmp_types.hrl").
-include("../../include/tracker.hrl").
-define(SNMP_USER, "tracker_probe_user").

%% beha_tracker_probe exports
-export([
    init/1,
    exec/1,
    info/0]).

%% snmpm_user exports
-export([
    handle_error/3,
    handle_agent/5,
    handle_pdu/4,
    handle_trap/3,
    handle_inform/3,
    handle_report/3
]).

init(#probe_server_state{
        probe  = #probe{tracker_probe_conf = Conf},
        target = #target{id = Name}
    } = S) ->
    #snmp_conf{
        ip          = IpString,
        port        = Port,
        version     = Version,
        community   = Community
    } = Conf,
    {ok, Ip} = inet:parse_address(IpString),
    SnmpConf = [
        {engine_id, "none"},
        {address,   Ip},
        {port  ,    Port},
        {version,   Version},
        {community, Community}
    ],
    snmpm:register_agent(?SNMP_USER, atom_to_list(Name), SnmpConf),
    S.

exec({_,#probe{
            tracker_probe_conf = #snmp_conf{
                agent_name  =  Agent,
                oids        =  Oids
            },
            timeout = Timeout
        }
    }) -> 
    Rep = snmpm:sync_get(?SNMP_USER, Agent, Oids, Timeout * 1000),
    case Rep of
        {error, Error} ->
            io:format("rep is error ~p~n",[Error]);
        {ok, SnmpReply, _Remaining} ->
            % from snmpm documentation: snmpm, Common Data Types 
            % snmp_reply() = {error_status(), error_index(), varbinds()}
            {_ErrStatus, _ErrId, VarBinds} = SnmpReply,
            lists:foreach(fun(X) ->
                io:format("rep is noError ~p~n",[X#varbind.value])
            end, VarBinds)
    end, 
    #probe_return{
        original_reply  = "hello world from snmp",
        timestamp       = tracker_misc:timestamp(second)
    }.

info() -> {ok, "snmp get and walk module"}.


%% snmpm_user behaviour
handle_error(_ReqId, _Reason, _UserData) ->
    io:format("handle_error ~p~n", [?MODULE]),
    ignore.

handle_agent(_Addr, _Port, _Type, _SnmpInfo, _UserData) ->
    io:format("handle_agent ~p~n", [?MODULE]),
    ignore.

handle_pdu(_TargetName, _ReqId, SnmpResponse, _UserData) ->
    io:format("handle_pdu ~p ~p~n", [?MODULE,SnmpResponse]),
    ignore.

handle_trap(_TargetName, _SnmpTrapInfo, _UserData) ->
    io:format("handle_trap ~p~n", [?MODULE]),
    ignore.

handle_inform(_TargetName, _SnmpInform, _UserData) ->
    io:format("handle_inform ~p~n", [?MODULE]),
    ignore.

handle_report(_TargetName, _SnmpReport, _UserData) ->
    io:format("handle_report ~p~n", [?MODULE]),
    ignore.
