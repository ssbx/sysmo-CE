% This file is part of "Enms" (http://sourceforge.net/projects/enms/)
% Copyright (C) 2012 <Sébastien Serre sserre.bx@gmail.com>
% 
% Enms is a Network Management System aimed to manage and monitor SNMP
% target, monitor network hosts and services, provide a consistent
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
% @private
-module(tracker_target_channel_sup).
-behaviour(supervisor).

-export([
    start_link/0,
    new/1,
    cold_start/1
]).

-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

new(Target) ->
    {ok, _} = supervisor:start_child(?MODULE, [Target]).

% @doc
% Called from tracker_app from his start_phase/3.
% @end
cold_start(ConfFile) ->
    % create the targets
    {ok, Targets} = file:consult(ConfFile),
    ok = lists:foreach(fun(Target) ->
        ?MODULE:new(Target)
    end, Targets).

init([]) ->
    {ok, 
        {
            {simple_one_for_one, 1, 60},
            [
                {
                    tracker_target_channel,
                    {tracker_target_channel, start_link, []},
                    transient,
                    2000,
                    worker,
                    [tracker_target_channel]
                }
            ]
        }
    }.
