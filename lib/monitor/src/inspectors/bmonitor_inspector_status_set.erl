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
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Enms. If not, see <http://www.gnu.org/licenses/>.
% @doc
% The most simple and mandatory inspector. It set re return status of the
% ProbeServer to the return status of the probe return.
% @end
-module(bmonitor_inspector_status_set).
-behaviour(monitor_inspector).
-include("include/monitor.hrl").


-export([
    info/0,
    init/2,
    inspect/4
]).

info() ->
    Info = 
"This inspector is very basic. It take the ModifiedProbe#probe{} and set the 
#probe.status value to the value of ProbeReturn#probe_return.status. In other
words it set the status of the probe from the status of the probe_return
without further inspection. This inspector should be the first called.",
    {ok, Info}.

init(_Conf, #probe{name=Name,status=Status}) ->
    monitor_alerts:notify_init(Name, Status),
    {ok, no_state}.

inspect(State, ProbeReturn, #probe{status=OldStatus} = _Orig, ModifiedProbe) ->
    Status   = ProbeReturn#probe_return.status,
    NewProbe = ModifiedProbe#probe{status = Status},
    case Status of
        OldStatus ->
            monitor_alerts:notify(ModifiedProbe#probe.name, Status);
        _ ->
            monitor_alerts:notify_move(ModifiedProbe#probe.name, Status)
    end,
    {ok, State, NewProbe}.
