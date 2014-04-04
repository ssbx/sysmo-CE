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
% @doc
% The module implementing this behaviour is used by a tracker_target_channel
% to store values returned by the probes.
% @end
-module(btracker_logger_text).
-behaviour(beha_tracker_logger).
-include("../../include/tracker.hrl").

-export([
    init/2,
    log/2,
    dump/1
]).

init(_Conf, #ps_state{
        target          = Target,
        probe           = Probe,
        loggers_state   = LoggersState} = ProbeServerState) -> 

    LogFile     = generate_filename(Target, Probe),
    {ok, Pid}   = tlogger_text_sup:start_logger(LogFile),
    NewLoggersState =  lists:keystore(?MODULE, 1, 
            LoggersState, {?MODULE, [{file_name, LogFile}, {log_srv, Pid}] }),
    {ok, 
        ProbeServerState#ps_state{
            loggers_state = NewLoggersState
        }
    }.

log(
        #ps_state{loggers_state = LState}, 
        #probe_return{original_reply = Msg, timestamp = T}
    ) ->
    LogSrv      = get_key(log_srv, LState),
    EncodedMsg  = list_to_binary(io_lib:format("~p>>> ~s", [T, Msg])),
    tlogger_text:log(LogSrv, EncodedMsg),
    ok.

dump(#ps_state{
        loggers_state   = LState,
        target          = #target{id = TId},
        probe           = #probe{name = PId}
    }) ->
    LogSrv  = get_key(log_srv, LState),
    Bin     = tlogger_text:dump(LogSrv),
    Pdu     = pdu('probeDump', {TId, PId, Bin}),
    Pdu.

pdu('probeDump', {TargetId, ProbeId, Binary}) ->
    {modTrackerPDU,
        {fromServer,
            {probeDump,
                {'ProbeDump',
                    atom_to_list(TargetId),
                    atom_to_list(ProbeId),
                    atom_to_list(?MODULE),
                    Binary}}}}.

generate_filename(Target, Probe) ->
    TargetDir   = Target#target.directory,
    ProbeName   = Probe#probe.name,
    FileName    = io_lib:format("~s.txt", [ProbeName]),
    filename:absname_join(TargetDir, FileName).

get_key(Key, TupleList) ->
    {?MODULE, Conf} = lists:keyfind(?MODULE, 1, TupleList),
    {Key, Value}    = lists:keyfind(Key, 1, Conf),
    Value.
