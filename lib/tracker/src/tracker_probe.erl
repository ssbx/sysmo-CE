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
% @doc
% @end
-module(tracker_probe).
-behaviour(gen_server).
-include("../include/tracker.hrl").

-export([
    init/1,
    handle_call/3, 
    handle_cast/2, 
    handle_info/2, 
    terminate/2, 
    code_change/3
]).

% for debug only
-export([
    handle_probe_return/3,
    handle_probe_return/4,
    handle_probe_return/5
]).

-export([
    start_link/1,
    probe_pass/1,
    external_event/2
]).


%%-------------------------------------------------------------
%%-------------------------------------------------------------
%% API
%%-------------------------------------------------------------
%%-------------------------------------------------------------

start_link({Target, #probe{name = Name} = Probe}) ->
    gen_server:start_link({local, Name}, ?MODULE, [Target, Probe], []).

-spec external_event(pid(), any()) -> ok.
% @doc
% Handle messages comming from the system and wich should be forwarded to the
% subscribers of the channel.
% @end
external_event(ProbeName, Pdu) ->
    gen_server:cast(ProbeName, {external_event, Pdu}).

%%-------------------------------------------------------------
%%-------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%-------------------------------------------------------------
%%-------------------------------------------------------------

%%-------------------------------------------------------------
%% INIT
%%-------------------------------------------------------------
init([Target, Probe]) ->
    S1  = #ps_state{
        target              = Target,
        probe               = Probe#probe{pid = self()},
        loggers_state       = [],
        inspectors_state    = []
    },
    gen_server:cast(self(), initial_pass),
    {ok, S2}    = init_loggers(S1),
    {ok, S3}    = init_inspectors(S2),
    {ok, SF}    = init_probe(S3),
    {ok, SF}.
        
    
%%-------------------------------------------------------------
%% HANDLE_CALL
%%-------------------------------------------------------------



% gen_channel calls
handle_call(get_perms, _F, #ps_state{probe = Probe} = S) ->
    {reply, Probe#probe.permissions, S};

handle_call({synchronize, #client_state{module = CMod} = CState},
        _F, #ps_state{probe = Probe} = S) ->
    supercast_mpd:subscribe_stage3(Probe#probe.name, CState),
    Pdus = log_dump(S),
    Pdus2 = [{CState, Pdu} || Pdu <- Pdus],
    % no need to filter witch acctrl because the stage1 synchronize have
    % allready do it.
    lists:foreach(fun({C_State, Pdu}) ->
        CMod:send(C_State, Pdu)
    end, Pdus2),
    {reply, ok, S};

%
handle_call(_R, _F, S) ->
    {noreply, S}.


%%-------------------------------------------------------------
% HANDLE_CAST
%%-------------------------------------------------------------
% launch a probe for the first time.
handle_cast(initial_pass, #ps_state{probe = Probe} = S) ->
    ?LOG("initial pass.........\n"),
    Step            = Probe#probe.step, 
    InitialLaunch   = tracker_misc:random(Step * 1000),
    {ok, TRef} = timer:apply_after(InitialLaunch, ?MODULE, probe_pass, [S]),
    {noreply, S#ps_state{tref = TRef}};

% PsState are equal, probe event.
handle_cast({next_pass,                 S    , PR}, 
            #ps_state{
                target  = Target,
                probe   = Probe} =      S   ) ->
    ?LOG("next pass.........\n"),
    supercast_mpd:multicast_msg(Probe#probe.name, {
            Probe#probe.permissions,
            pdu(probeReturn, {PR, Target#target.id, Probe#probe.name})}),
    log(S, PR),
    After = Probe#probe.step * 1000,
    {ok, TRef} = timer:apply_after(After, ?MODULE, probe_pass, [S]),
    {noreply, S#ps_state{tref = TRef}};

% else update the event handler, target_channel (broad event)
handle_cast({next_pass, 
        #ps_state{
            probe   = Probe,
            target  = Target
        } = NewState,
        ProbeReturn
    }, _OldState) ->
    ?LOG("next pass.........\n"),

    tracker_target_channel:update(
        Target#target.id,
        Probe#probe.id,
        {Probe, ProbeReturn}
    ),
    supercast_mpd:multicast_msg(Probe#probe.name, {
            Probe#probe.permissions,
            pdu(probeReturn, 
                {ProbeReturn, Target#target.id, Probe#probe.name})}),
    log(NewState, ProbeReturn#probe_return{is_event = true}),
    After = Probe#probe.step * 1000,
    {ok, TRef} =  timer:apply_after(After, ?MODULE, probe_pass, [NewState]),
    {noreply, NewState#ps_state{tref = TRef}};

handle_cast({external_event, Pdu}, #ps_state{probe = P} = S) ->
    supercast_mpd:multicast_msg(P#probe.name, {P#probe.permissions, Pdu}),
    {noreply, S};

% PARENT CHILD ASSOCIATION
% a child allready triggered the child_status_request.
handle_cast({child_status_request, Caller},
        #ps_state{pending_child_request = true} = S) ->
    #ps_state{pending_callers = Callers} = S,
    {noreply, S#ps_state{
            pending_callers = lists:append([Caller], [Callers])}};

handle_cast({child_status_request, Caller},
        #ps_state{pending_child_request = false}  = S) ->
    #ps_state{probe = #probe{status = Status}}    = S,
    #ps_state{probe = #probe{name = Name}}        = S,
    #ps_state{tref = TRef}                        = S,
    #ps_state{pending_callers = Callers}          = S,
    case Status of
        'CRITICAL' -> 
            % do nothing, child_status_request has been done by this probe
            tracker_probe:child_info(Caller, Name, Status),
            {noreply, S};
        'UNKNOWN' -> 
            % do nothing, child_status_request has been done by this probe
            tracker_probe:child_info(Caller, Name, Status),
            {noreply, S};
        _ -> % We must check.
            % try to STOP the current timer,
            case timer:cancel(TRef) of
                {ok, _}  -> % the fun has not been launched start now.
                    ?LOG("job canceled~n"),
                    {ok, NewTRef} = timer:apply_after(0, ?MODULE, probe_pass, [S]),
                    % fill pending_callers, and request to true
                    % pending_child_request will be catched by handle_cast/next_pass
                    {noreply, S#ps_state{
                        tref                    = NewTRef,
                        pending_child_request   = true,
                        pending_callers         = lists:append([Caller], [Callers] )}
                    };
                {error, _} -> % The return is in the gen_server queu do nothing
                    ?LOG("job return in queu~n"),
                    % fill pending_callers, and request to true
                    % pending_child_request will be catched by handle_cast/next_pass
                    {noreply, S#ps_state{
                        pending_child_request   = true,
                        pending_callers         = lists:append([Caller], [Callers] )}
                    }
            end
    end;

handle_cast(_R, S) ->
    io:format("Unknown message ~p ~p ~p ~p~n", [?MODULE, ?LINE, _R, S]),
    {noreply, S}.


%%-------------------------------------------------------------
%% HANDLE_INFO
%%-------------------------------------------------------------
handle_info(I, S) ->
    io:format("handle_info ~p ~p ~p~n", [?MODULE, I, S]),
    {noreply, S}.


%%-------------------------------------------------------------
%% TERMINATE  
%%-------------------------------------------------------------
terminate(_R, _) ->
    normal.


%%-------------------------------------------------------------
%% CODE_CHANGE
%%-------------------------------------------------------------
code_change(_O, S, _E) ->
    io:format("code_change ~p ~p ~p ~p~n", [?MODULE, _O, _E, S]),
    {ok, S}.



%%-------------------------------------------------------------
%%-------------------------------------------------------------
%% PRIVATE FUNS
%%-------------------------------------------------------------
%%-------------------------------------------------------------
-spec probe_pass(#ps_state{}) -> ok.
% @doc
% It is the spawned proc who call the "gen_probe" module defined in the 
% #probe{} record. Called from "initial_pass" and "next_pass" modules.
% @end
probe_pass(#ps_state{probe  = Probe } = S) ->
    Mod         = Probe#probe.tracker_probe_mod,
    ProbeReturn = Mod:exec({S, Probe}),
    NewS        = inspect(S, ProbeReturn),
    next_pass(NewS, ProbeReturn).

-spec next_pass(#ps_state{}, #probe_return{}) -> ok.
% @doc
% called from ?MODULE:probe_pass which trigger another probe_pass.
% @end
next_pass(#ps_state{probe = Probe} = State, ProbeReturn) ->
    gen_server:cast(Probe#probe.pid, {next_pass, State, ProbeReturn}).
 
% INIT PROBE
% TODO keystore conf here
-spec init_probe(#ps_state{}) -> #ps_state{}.
init_probe(#ps_state{
        probe = #probe{tracker_probe_mod = Mod}
    } = S) ->
    SF = Mod:init(S),
    {ok, SF}.

% LOGGERS
% TODO keystore conf here
-spec init_loggers(#ps_state{}) -> #ps_state{}.
init_loggers(#ps_state{probe = Probe} = State) ->
    NewState = lists:foldl(
        fun(#logger{module = Mod, conf = Conf}, PSState) ->
            {ok, NPSState} = Mod:init(Conf, PSState),
            NPSState
        end, State, Probe#probe.loggers),
    {ok, NewState}.

% TODO send conf here
-spec log(#ps_state{}, {atom(), any()}) -> ok.
log(#ps_state{probe = Probe} = PSState, Msg) ->
    lists:foreach(fun(#logger{module = Mod}) ->
        spawn(fun() -> Mod:log(PSState, Msg) end)
    end, Probe#probe.loggers),
    ok.

-spec log_dump(#ps_state{}) -> any().
log_dump(#ps_state{probe = Probe} = PSState) ->
    L = [Mod:dump(PSState) || 
            #logger{module = Mod} <- Probe#probe.loggers],
    L2 = lists:filter(fun(Element) ->
        case Element of
            ignore  -> false;
            _       -> true
        end
    end, L),
    L2.

% INSPECTORS
% TODO keystore conf here
-spec init_inspectors(#ps_state{}) -> #ps_state{}.
init_inspectors(#ps_state{probe = Probe} = State) ->
    Inspectors = Probe#probe.inspectors,
    NewState = lists:foldl(fun(#inspector{module = Mod, conf = Conf}, S) ->
        {ok, NewState} = Mod:init(Conf, S),
        NewState 
    end, State, Inspectors),
    {ok, NewState}.

% TODO send conf here
-spec inspect(#ps_state{}, Msg::tuple()) -> #ps_state{}.
inspect(#ps_state{probe = Probe} = State, Msg) ->
    Inspectors = Probe#probe.inspectors,
    {State, NewState, Msg} = lists:foldl(
        fun(#inspector{module = Mod}, {Orig, Modified, Message}) ->
            {ok, New} = Mod:inspect(Orig, Modified, Message),
            {Orig, New, Message}
        end, {State, State, Msg}, Inspectors),
    NewState.

% @private
pdu(probeReturn, {
        #probe_return{ 
            status      = Status,
            original_reply = OriginalReply,
            timestamp   = Timestamp,
            key_vals    = KeyVals
        },
        ChannelId, ProbeId}) ->
    {modTrackerPDU,
        {fromServer,
            {probeReturn,
                {'ProbeReturn',
                    atom_to_list(ChannelId),
                    atom_to_list(ProbeId),
                    atom_to_list(Status),
                    OriginalReply,
                    Timestamp,
                    make_key_values(KeyVals)
                }}}}.

make_key_values(K) ->
    make_key_values(K, []).
make_key_values([], S) ->
    S;
make_key_values([{K,V} | T], S) when is_list(V) ->
    make_key_values(T, [{'Property', K, V} | S]);
make_key_values([{K,V} | T], S) when is_integer(V) ->
    make_key_values(T, [{'Property', K, integer_to_list(V)} | S]);
make_key_values([{K,V} | T], S) when is_float(V) ->
    make_key_values(T, [{'Property', K, float_to_list(V, [{decimals, 10}])} | S]);
make_key_values([{K,V} | T], S) when is_atom(V) ->
    make_key_values(T, [{'Property', K, atom_to_list(V)} | S]).



















%
handle_probe_return(State, ProbeReturn, NewState) ->
    #ps_state{pending_child_request = Request}    = State,
    #ps_state{probe = Probe1}                     = State,
    #ps_state{probe = Probe2}                     = NewState,
    case Probe1 of
        Probe2 ->
            StatusMove = false;
        _ ->
            StatusMove = true
    end,
    case Request of
        true ->
            PendingRequest = true;
        false ->
            PendingRequest = false
    end,
    handle_probe_return(
        StatusMove,
        PendingRequest,
        State,
        NewState,
        ProbeReturn).

handle_probe_return(StatusMove, _PendingRequest = false, S, NS, PR) ->
    handle_probe_return(StatusMove, S, NS, PR);

handle_probe_return(StatusMove, _PendingRequest = true, S, NS, PR) ->
    % do something then
    handle_probe_return(StatusMove, S, NS, PR).

handle_probe_return(_StatusMove = false, S, _NS, PR) ->
    #ps_state{probe  = Probe}     = S,
    #ps_state{target = Target}    = S,
    supercast_mpd:multicast_msg(
        Probe#probe.name, {
            Probe#probe.permissions,
            pdu(probeReturn, {PR, Target#target.id, Probe#probe.name})
        }
    ),
    log(S, PR),
    After = Probe#probe.step * 1000,
    {ok, TRef} = timer:apply_after(After, ?MODULE, probe_pass, [S]),
    S#ps_state{tref = TRef};

handle_probe_return(_StatusMove = true, _S, NS, PR) ->
    #ps_state{probe  = Probe}     = NS,
    #ps_state{target = Target}    = NS,
    tracker_target_channel:update(
        Target#target.id,
        Probe#probe.id,
        {Probe, PR}
    ),
    supercast_mpd:multicast_msg(
        Probe#probe.name, {
            Probe#probe.permissions,
            pdu(probeReturn, {
                PR,
                Target#target.id, Probe#probe.name
            })
        }
    ),
    log(NS, PR#probe_return{is_event = true}),
    After       = Probe#probe.step * 1000,
    {ok, TRef}  =  timer:apply_after(After, ?MODULE, probe_pass, [NS]),
    NS#ps_state{tref = TRef}.
