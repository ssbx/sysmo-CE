% Copyright (C) 2014, Sebastien Serre <sserre.bx@gmail.com>
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

-module(errd4j).
-include("include/errd4j.hrl").
-behaviour(gen_server).

% gen_server
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-export([
    start_link/0,
    assert_init/0
]).


-export([
    create/3,
    create/4,
    multi_create/1,

    update/3,
    multi_update/1,
    sysmo_ifperf_update/2

    % MAYBE
    %update_fetch/0,
    %updates_fetch/0,
]).

-record(state, {
    errd4j_pid      = undefined,
    replies_waiting = [],
    java_com        = "",
    assert_init     = undefined
}).

-define(ASSERT_TIMEOUT, 5000).


-spec multi_update(Updates::[tuple()]) -> ok.
% @doc
% Send multiple update/3 in one call. Arg is a list of tuple.
% Each tuple have the same content as update/3.
% @end
multi_update(Updates) ->
    gen_server:call(?MODULE, {call_errd4j, {multi_update, {Updates}}}).

-spec sysmo_ifperf_update(Indexes::[{Index::integer(), File::string()}], Walk::[tuple()]) -> ok.
% @private
% @doc
% Walk is a list of tuple returned by snmpman:walk_table/2.
% @end
sysmo_ifperf_update(Indexes, Walk) ->
    gen_server:call(?MODULE, {call_errd4j, {sysmo_ifperf_update, {Indexes,Walk}}}).

-spec update(File::string(), Updates::{string(), integer()}, Timstamp::integer()) -> ok.
% @doc
% Execute an update to a single rrdfile.
% example: Updates = [{"MaxRoundTrip", 3000}, {"MinRoundTrip", 399}],
% @end
update(File, Updates, Timestamp) ->
    Args = {File, Updates, Timestamp},
    gen_server:call(?MODULE, {call_errd4j, {update, Args}}).
    

-spec multi_create(Args::list()) -> ok.
% @doc
% Send multiple create command in one call. Args is a list of tuples with the
% same elements as in create/4 call.
% Example = [{"jojo.rrd",300,[{"speed", "COUNTER", 600, 0, 'Nan'}],"default"}...]
% @end
multi_create(Args) ->
    gen_server:call(?MODULE, {call_errd4j, {multi_create, {Args}}}).
    
    
-spec create(File::string(), Step::integer(), DDs::[]) -> ok.
% @doc
% Same as create(File,Step,DDs,"default")
% @end
create(File,Step, DSs) ->
    create(File,Step,DSs,"default").

-spec create(File::string(), Step::integer(), DSs::[], RRAType::string()) -> ok.
% @doc
% Where RRAType is "default" or "precise"
% File: a string represnting the rrd file created
% Step: an integer
% DSs: [{DsName::string(), DsType::string(), HeartBeat::integer(), Min::integer(), Max::integer()}]
%   example: [{"speed", "COUNTER", 600, 0, 'Nan'}]
% @end
create(File, Step, DSs, RRAType) ->
    Args = {File,Step,DSs,RRAType},
    gen_server:call(?MODULE, {call_errd4j, {create, Args}}).





% @private
start_link() ->
    Ret = gen_server:start_link({local, ?MODULE}, ?MODULE, [], []),
    ok = assert_init(),
    Ret.

% @private
% @doc
% Called by start_link to ensure initialisation before returning.
% @end
assert_init() ->
    gen_server:call(?MODULE, assert_init, ?ASSERT_TIMEOUT).



% GEN_SERVER
% @private
init([]) ->
    process_flag(trap_exit, true),
    {ok, JavaConf}  = application:get_env(errd4j, java_node),
    JavaCommand     = proplists:get_value(java_com, JavaConf),
    gen_server:cast(?MODULE, boot),
    {ok, #state{java_com = JavaCommand}}.

% CALL 
% @private
handle_call(assert_init, F, #state{errd4j_pid = undefined} = S) ->
    {noreply, S#state{assert_init = F}};
handle_call(assert_init, _F, S) ->
    {reply, ok, S};

handle_call({call_errd4j, {Command, Payload}}, From, 
        #state{errd4j_pid = Errd4j, replies_waiting = RWait} = S) ->
    Errd4j ! {Command, From, Payload},
    {noreply, S#state{replies_waiting = [From|RWait]}}.


% CAST
% @private
handle_cast(boot, #state{java_com = JavaCommand} = S) ->
    boot(JavaCommand),
    {noreply, S};

handle_cast(_,S) ->
    {noreply, S}.


% INFO
% @private
handle_info({Pid, errd4j_running}, S) ->
    io:format("receive init~n"),
    case S#state.assert_init of
        undefined -> 
            ok;
        F ->
            gen_server:reply(F, ok)
    end,
    erlang:link(Pid),
    {noreply, 
        S#state{
            errd4j_pid      = Pid,
            replies_waiting = [],
            assert_init     = undefined
        }
    };

% @private
handle_info(stop, S) ->
    io:format("received stop~n"),
    {noreply, S};

handle_info({reply, From, Reply}, #state{replies_waiting = RWait} = S) ->
    gen_server:reply(From, Reply),
    {noreply, 
        S#state{
            replies_waiting = lists:delete(From, RWait)
        }
    };

handle_info({'EXIT', Pid, Reason}, #state{errd4j_pid = Pid} = S) ->
    io:format("rrd4j EXIT with reason: ~p~n", [Reason]),
    {stop, Reason, S};

handle_info(_I, S) ->
    io:format("received handle info: ~p~n", [_I]),
    {noreply, S}.


% TERMINATE
% @private
terminate(_,_) ->
    ok.


% CHANGE
% @private
code_change(_,S,_) ->
    {ok, S}.


% PRIVATE
boot(JavaCommand) ->
    erlang:spawn(os,cmd,[JavaCommand]).
