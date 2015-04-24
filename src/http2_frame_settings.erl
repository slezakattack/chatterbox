-module(http2_frame_settings).

-define(SETTINGS_HEADER_TABLE_SIZE,         <<16#1>>).
-define(SETTINGS_ENABLE_PUSH,               <<16#2>>).
-define(SETTINGS_MAX_CONCURRENT_STREAMS,    <<16#3>>).
-define(SETTINGS_INITIAL_WINDOW_SIZE,       <<16#4>>).
-define(SETTINGS_MAX_FRAME_SIZE,            <<16#5>>).
-define(SETTINGS_MAX_HEADER_LIST_SIZE,      <<16#6>>).

-include("http2.hrl").

-behaviour(http2_frame).

-export([
         format/1,
         read_binary/2,
         send/2,
         ack/1
        ]).

-spec format(settings()) -> iodata().
format(#settings{
        header_table_size        = HTS,
        enable_push              = EP,
        max_concurrent_streams   = MCS,
        initial_window_size      = IWS,
        max_frame_size           = MFS,
        max_header_list_size     = MHLS
    }) ->
    lists:flatten(
        io_lib:format("[Settings: "
        " header_table_size        = ~p,"
        " enable_push              = ~p,"
        " max_concurrent_streams   = ~p,"
        " initial_window_size      = ~p,"
        " max_frame_size           = ~p,"
        " max_header_list_size     = ~p~n]", [HTS,EP,MCS,IWS,MFS,MHLS])).

-spec read_binary(binary(), frame_header()) ->
    {ok, payload(), binary()} |
    {error, term()}.
read_binary(Bin, _Header = #frame_header{length=0}) ->
    {ok, <<>>, Bin};
read_binary(Bin, _Header = #frame_header{length=Length}) ->
    <<SettingsBin:Length/binary,Rem/bits>> = Bin,
    Settings = parse_settings(SettingsBin),
    {ok, Settings, Rem}.

-spec parse_settings(binary()) -> settings().
parse_settings(Bin) ->
    parse_settings(Bin, #settings{}).

-spec parse_settings(binary(), settings()) -> settings().
parse_settings(<<0,3,Val:4/binary,T/binary>>, S) ->
    parse_settings(T, S#settings{max_concurrent_streams=binary:decode_unsigned(Val)});
parse_settings(<<0,4,Val:4/binary,T/binary>>, S) ->
    parse_settings(T, S#settings{initial_window_size=binary:decode_unsigned(Val)});
parse_settings(<<0,5,Val:4/binary,T/binary>>, S) ->
    parse_settings(T, S#settings{max_frame_size=binary:decode_unsigned(Val)});
parse_settings(<<>>, Settings) ->
    Settings.

-spec send(socket(), settings()) -> ok | {error, term()}.
send({Transport, Socket}, _Settings) ->
    %% TODO: hard coded settings frame. needs to be figured out from
    %% _Settings. Or not. We can have our own settings and they can be
    %% different.  Also needs to be compared to ?DEFAULT_SETTINGS and
    %% only send the ones that are different or maybe it's the fsm's
    %% current settings.  figure out later
    Header = <<12:24,?SETTINGS:8,16#0:8,0:1,0:31>>,

    Payload = <<3:16,
                100:32,
                4:16,
                65535:32>>,
    Frame = [Header, Payload],
    lager:debug("sending settings ~p", [Frame]),
    Transport:send(Socket, Frame).

-spec ack(socket()) -> ok | {error, term()}.
ack({Transport,Socket}) ->
    Transport:send(Socket, <<0:24,4:8,1:8,0:1,0:31>>).