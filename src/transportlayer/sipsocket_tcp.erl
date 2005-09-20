%%%-------------------------------------------------------------------
%%% File    : sipsocket_tcp.erl
%%% Author  : Fredrik Thulin <ft@it.su.se>
%%% Descrip.: TCP/TLS sipsocket module. Interface module to the
%%%           tcp_dispatcher gen_server process that shepherds all
%%%           TCP/TLS connection handler processes.
%%%
%%% Created : 15 Dec 2003 by Fredrik Thulin <ft@it.su.se>
%%%-------------------------------------------------------------------
-module(sipsocket_tcp).
%%-compile(export_all).

-behaviour(sipsocket).

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([start_link/0,
	 send/5,
	 is_reliable_transport/1,
	 get_socket/1,
	 get_raw_socket/1
	]).

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------
-include("socketlist.hrl").
-include("sipsocket.hrl").

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------


%%====================================================================
%% External functions
%%====================================================================

start_link() ->
    tcp_dispatcher:start_link().

%%--------------------------------------------------------------------
%% Function: send(SipSocket, Proto, Host, Port, Message)
%%           SipSocket = sipsocket record()
%%           Proto     = atom(), tcp | tcp6 | tls | tls6
%%           Host      = string()
%%           Port      = integer()
%%           Message   = term(), I/O list to send
%% Descrip.: Send a SIP message. Get the tcp_connection process from
%%           the sipsocket, and request it to send the message.
%% Returns : SendRes         |
%%           {error, Reason}
%%           SendRes = term(), whatever the socket module (gen_tcp or
%%                     ssl) send-function returns. Typically 'ok' or
%%                     {error, _Something}
%%           Reason = string()
%%--------------------------------------------------------------------
send(#sipsocket{proto=SProto}, Proto, _Host, Port, _Message) when is_integer(Port), SProto /= Proto ->
    {error, "Protocol mismatch"};
send(SipSocket, _Proto, Host, Port, Message) when is_record(SipSocket, sipsocket), is_integer(Port) ->
    %% Proto matches the one in SipSocket, so it can't be the wrong one when
    %% we extract the connection handler pid from SipSocket.
    SPid = SipSocket#sipsocket.pid,
    Timeout = get_timeout(SipSocket#sipsocket.proto),
    case catch gen_server:call(SPid, {send, {Host, Port, Message}}, Timeout) of
	{send_result, Res} ->
	    Res;
	{'EXIT', Reason} ->
	    Msg = io_lib:format("sipsocket_tcp failed sending through pid ~p : ~p",
				[SPid, Reason]),
	    {error, lists:flatten(Msg)}
    end.

%%--------------------------------------------------------------------
%% Function: get_socket(Dst)
%%           Dst = sipdst record()
%% Descrip.: Get a socket, cached or new, useable to send messages to
%%           this destination.
%% Returns : SipSocket       |
%%           {error, Reason}
%%           SipSocket = sipsocket record()
%%           Reason    = string()
%%--------------------------------------------------------------------
%%
%% Protocol is 'tls' or 'tls6'
%%
get_socket(#sipdst{proto=Proto}=Dst) when Proto == tls; Proto == tls6 ->
    case yxa_config:get_env(tls_disable_client) of
	{ok, false} ->
	    Timeout = get_timeout(Proto),
	    case catch gen_server:call(tcp_dispatcher, {get_socket, Dst}, Timeout) of
		{error, E} ->
		    {error, E};
		{ok, Socket} ->
		    Socket;
		{'EXIT', Reason} ->
		    Msg = io_lib:format("sipsocket_tcp failed fetching TLS socket : ~p",
					[Reason]),
		    {error, lists:flatten(Msg)}
		end;
	{ok, true} ->
	    {error, "TLS client disabled"}
    end;
%%
%% Protocol is 'tcp' or 'tcp6'
%%
get_socket(#sipdst{proto=Proto}=Dst) when Proto == tcp; Proto == tcp6 ->
    Timeout = get_timeout(Dst#sipdst.proto),
    case catch gen_server:call(tcp_dispatcher, {get_socket, Dst}, Timeout) of
	{error, E} ->
	    {error, E};
	{ok, Socket} ->
	    Socket;
	{'EXIT', Reason} ->
	    Msg = io_lib:format("sipsocket_tcp failed fetching TLS socket : ~p",
				[Reason]),
            {error, lists:flatten(Msg)}
    end.

%%--------------------------------------------------------------------
%% Function: get_raw_socket(Socket)
%%           Socket  = sipsocket record()
%% Descrip.: Get the raw TCP/UDP/TLS socket from the socket handler.
%%           Be careful with what you do with the raw socket - don't
%%           use it for sending/receiving for example. Intended for
%%           use in extractin certificate information of an SSL socket
%%           or similar.
%% Returns : {ok, RawSocket} |
%%           {error, Reason}
%%           RawSocket = term()
%%           Reason    = string()
%%--------------------------------------------------------------------
get_raw_socket(SipSocket) when is_record(SipSocket, sipsocket) ->
    SPid = SipSocket#sipsocket.pid,
    Timeout = get_timeout(SipSocket#sipsocket.proto),
    case catch gen_server:call(SPid, get_raw_socket, Timeout) of
	{ok, RawSocket} ->
	    {ok, RawSocket};
	{'EXIT', Reason} ->
	    Msg = io_lib:format("sipsocket_tcp failed getting raw socket from pid ~p : ~p",
				[SPid, Reason]),
	    {error, lists:flatten(Msg)}
    end.

%%--------------------------------------------------------------------
%% Function: is_reliable_transport(_SipSocket)
%% Descrip.: Return true. This sipsocket modules transports are
%%           reliable. The meaning of reliable is that they handle
%%           resends automatically, so the transaction layer does not
%%           have to set up timers to resend messages.
%% Returns : true
%%--------------------------------------------------------------------
is_reliable_transport(_) -> true.


%%====================================================================
%% Internal functions
%%====================================================================

get_timeout(tcp) -> 1500;
get_timeout(tcp6) -> 1500;
get_timeout(tls) -> 5000;
get_timeout(tls6) -> 5000.