%% this module handles hex data:
%% * hex string to integer
%% * integer to hex string
%% * 
%%
%%--------------------------------------------------------------------

-module(hex).

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
	 to/1, 
	 to/2, 
	 to_hex_string/1,
	 to_int/1,
	 from/1
	]).

%%--------------------------------------------------------------------
%% Internal exports
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Include files
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------

%%====================================================================
%% External functions
%%====================================================================

%%--------------------------------------------------------------------
%% Function: 
%% Descrip.: 
%% Returns : 
%%--------------------------------------------------------------------
to(_, 0) ->
    [];
to(Number, N) when integer(Number), N > 0 ->
    lists:append(to(Number div 16, N - 1), [lists:nth(Number rem 16 + 1,
						      [$0, $1, $2, $3,
						       $4, $5, $6, $7,
						       $8, $9, $a, $b,
						       $c, $d, $e, $f])]).

to(Binary) when binary(Binary) ->
    A = binary_to_list(Binary),
    B = lists:map(fun(C) ->
			  to(C, 2)
		  end, A),
    lists:flatten(B).


%%--------------------------------------------------------------------
%% Function: to_hex_string(Int)
%%           Int = integer()
%% Descrip.: convert Int into string() in hex encoding
%% Returns : string() containing $0-$F, upper case is used for $A-$F
%%--------------------------------------------------------------------
%% the basic idea of this function is to alway take the least 
%% significant (right) 4 bits (hex number) and add as a hex char to
%% the ones allready processed in HexString 

%% this function is not defined for negative numbers 
to_hex_string(Int) when Int >= 0 ->
    Mask = 2#1111,
    to_hex_string(Int bsr 4, [to_hex_char(Int band Mask)] ).

to_hex_string(0, HexString) ->
    HexString;
to_hex_string(IntRest, HexString) ->
    Mask = 2#1111,
    to_hex_string(IntRest bsr 4, [to_hex_char(IntRest band Mask) | HexString] ).

%% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
%% Function: to_hex_char(Int)
%%           Int = integer(), 0-15
%% Descrip.: convert Int into char() in hex encoding
%% Returns : integer(), $0-$F, upper case is used for $A-$F
%% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
to_hex_char(Int) when (Int >= 0), (Int =< 9) -> 
    $0 + Int;
to_hex_char(Int) when (Int >= 10), (Int =< 15) -> 
    $A + Int -10.


%%--------------------------------------------------------------------
%% Function: from(String)
%%           to_int(String)
%%           String = string(), a numeric string of hex values (0-9, 
%%           A-F and a-f can be used)
%% Descrip.: convert hex string into a integer
%% Returns : integer()
%%--------------------------------------------------------------------
to_int(String) ->
    from(String, 0).

from(String) ->
    from(String, 0).

%% N keeps the current acumulated value, each new char encountered when
%% scaning to the right, is added and N is shifted 4 bits to the left
%% Note: "N * 16" could be replaced by "N bsl 4"

from([], N) ->
    N;

from([C | String], N) when C >= $0, C =< $9 ->
    M = N * 16 + (C - $0),
    from(String, M);

from([C | String], N) when C >= $a, C =< $f ->
    M = N * 16 + (C - $a + 10),
    from(String, M);

from([C | String], N) when C >= $A, C =< $F ->
    M = N * 16 + (C - $A + 10),
    from(String, M).

