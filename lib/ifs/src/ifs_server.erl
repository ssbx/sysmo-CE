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
% @private
-module(ifs_server).
-behaviour(gen_server).
-include("../include/ifs.hrl").

-export([
    init/1,
    handle_call/3, 
    handle_cast/2, 
    handle_info/2, 
    terminate/2, 
    code_change/3
]).

-export([
    start_link/1,
    client_msg/2,
    dump/0
]).

-record(state, {
    auth_mod
}).
 

%%-------------------------------------------------------------
%% API
%%-------------------------------------------------------------
% @private
start_link(ServerConf) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, ServerConf, []).


which_auth() ->
    gen_server:call(?MODULE, {get, auth_mod}).


% API FROM CLIENTS
client_msg(Msg, ClientState) ->
    io:format("~p RECEIVED: ~p~n", [?MODULE, Msg]),
    handle_client_msg(Msg, ClientState).

% DEBUG
% @private
dump() ->
    gen_server:call(?MODULE, dump).

%%-------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%-------------------------------------------------------------
% @private
init(AuthModule) ->
    {ok, #state{auth_mod = AuthModule}}.

% @private
handle_call(dump, _F, S) ->
    {reply, S, S};

handle_call({get, auth_mod}, _F, #state{auth_mod = AuthMod} = S) ->
    {reply, AuthMod, S};

% CLIENT RELATED CALLS
handle_call(_R, _F, S) ->
    io:format("handle_call ~p~p~n", [?MODULE, _R]),
    {noreply, S}.

% CAST
% @private
handle_cast(_R, S) ->
    io:format("handle_cast ~p~p~n", [?MODULE, _R]),
    {noreply, S}.

% OTHER
% @private
handle_info(_I, S) ->
    {noreply, S}.

% @private
terminate(_R, _S) ->
    normal.

% @private
code_change(_O, S, _E) ->
    {ok, S}.

% CLIENT CALL
% @private
handle_client_msg(connect, ClientState) ->
    send(ClientState, pdu(authReq, ldap));

handle_client_msg(disconnect, ClientState) ->
    ifs_mpd:client_disconnect(ClientState);

handle_client_msg(
        {message, 
            {modIfPDU, 
                {fromClient,
                    {authResp,
                        {'AuthResp', 
                            Name,
                            Password
        }   }   }   }   },  #client_state{module = CMod} = ClientState) ->
    AuthMod = which_auth(),
    case AuthMod:authenticate(Name, Password) of
        {ok, Groups} ->
            MainChans = ifs_mpd:main_chans(),
            CMod:auth_set(success, ClientState, Name, Groups, MainChans),
            send(ClientState,pdu(authAck, {Groups, MainChans}));
        fail    ->
            send(ClientState, pdu(authErr, {Name, Password}))
    end;

handle_client_msg(
        {message, 
            {modIfPDU, 
                {fromClient,
                    {subscribe,
                        Channel
        }   }   }   }, CState) ->
    Chan = erlang:list_to_atom(Channel),
    case ifs_mpd:subscribe_stage1(Chan, CState) of
        error ->
            send(CState, pdu(subscribeErr, Channel));
        ok ->
            send(CState, pdu(subscribeOk, Channel)),
            ifs_mpd:subscribe_stage2(Chan,CState)
    end;
            

handle_client_msg(
        {message, 
            {modIfPDU, 
                {fromClient,
                    Other
        }   }   }, _) ->
    io:format("~p RECEIVED UNKNOWN ~p~n", [?MODULE, Other]).


% server PDUs
% @private
pdu(authReq, Type) ->
    {modIfPDU, 
        {fromServer, 
            {authReq, 
                Type }}};

pdu(authAck, {Groups, StaticChans}) ->
    StaticChansAsString = lists:foldl(fun(Atom, Accum) ->
        [{'ChanInfo', atom_to_list(Atom), create} | Accum]
    end, [], StaticChans),
    {modIfPDU, 
        {fromServer,
            {authAck,
                {'AuthAck',
                    Groups,
                    StaticChansAsString }}}};

pdu(authErr, {Name, Password}) ->
    {modIfPDU,
        {fromServer,
            {authError,
                {'AuthError',
                    badPass,
                    Name,
                    Password }}}};

pdu(subscribeOk, Module) ->
    {modIfPDU, 
        {fromServer, 
            {subscribeOk, 
                Module }}};

pdu(subscribeErr, Module) ->
    {modIfPDU, 
        {fromServer,
            {subscribeErr, 
                Module }}};

pdu(unsubscribeOk, Module) ->
    {modIfPDU, 
        {fromServer, 
            {unsubscribeOk, 
                Module }}};

pdu(unsubscribeErr, Module) ->
    {modIfPDU, 
        {fromServer, 
            {unsubscribeErr, 
                Module }}};

pdu(chanInfo, {Module, Channel, Type}) ->
    {modIfPDU,
        {fromServer,
            {chanInfo,
                {'ChanInfo',
                    Module,
                    Channel,
                    Type }}}}.


send(#client_state{module = CMod} = ClientState, Msg) ->
    io:format("~p SENDING ~p~n", [?MODULE, Msg]),
    CMod:send(ClientState, Msg).
