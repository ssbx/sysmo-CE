%% Generated by the Erlang ASN.1 compiler version:3.0.1
%% Purpose: Erlang record definitions for each named and unnamed
%% SEQUENCE and SET, and macro definitions for each value
%% definition,in module Supercast



-ifndef(_SUPERCAST_HRL_).
-define(_SUPERCAST_HRL_, true).

-record('AuthAck',{
groups, staticChans}).

-record('AuthError',{
error, userId, pass}).

-record('AuthResp',{
userId, pass}).

-record('ServerInfo',{
authType, dataPort, dataProto}).

-record('ChanInfo',{
channel, type}).

-record('Subscribe',{
queryId, chan}).

-record('Unsubscribe',{
queryId, chan}).

-record('SubscribeOk',{
queryId, chan}).

-record('SubscribeErr',{
queryId, chan}).

-record('UnsubscribeOk',{
queryId, chan}).

-record('UnsubscribeErr',{
queryId, chan}).

-endif. %% _SUPERCAST_HRL_