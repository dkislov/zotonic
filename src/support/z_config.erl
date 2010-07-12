%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2010 Marc Worrell
%% @doc Simple configuration server.  Holds and updates the global config in priv/config

%% Copyright 2010 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.


-module(z_config).
-author("Marc Worrell <marc@worrell.nl>").
-behaviour(gen_server).

% gen_server exports
-export([
    start_link/0,
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

% API export
-export([
    get/1,
    set/2
]).

-record(state, {config=[]}).

-include_lib("zotonic.hrl").

%%====================================================================
%% API
%%====================================================================
%% @spec start_link() -> {ok,Pid} | ignore | {error,Error}
%% @doc Starts the server
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get(Config) ->
    gen_server:call(?MODULE, {get, Config}).

set(Config, Value) ->
    gen_server:cast(?MODULE, {set, Config, Value}).


%%====================================================================
%% gen_server callbacks
%%====================================================================

%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore               |
%%                     {stop, Reason}
%% @doc Initiates the server.
init(_Args) ->
    {ok, Config} = ensure_config(),
    {ok, #state{config=Config}}.


%% @spec handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @doc Get a value
handle_call({get, Prop}, _From, State) ->
    {reply, proplists:get_value(Prop, State#state.config), State};

%% @doc Trap unknown calls
handle_call(Message, _From, State) ->
    {stop, {unknown_call, Message}, State}.

%% @doc Set a value
handle_cast({set, Prop, Value}, State) ->
    Config = [ {Prop, Value} | proplists:delete(Prop, State#state.config)],
    write_config(Config),
    {no_reply, State#state{config=Config}};

%% @doc Trap unknown casts
handle_cast(Message, State) ->
    {stop, {unknown_cast, Message}, State}.

%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% @doc Handling all non call/cast messages
handle_info(Info, State) ->
    ?DEBUG({unknown_info, Info}),
    {noreply, State}.


%% @spec terminate(Reason, State) -> void()
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
terminate(_Reason, _State) ->
    ok.

%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%====================================================================
%% support functions
%%====================================================================


ensure_config() ->
    File = config_file(),
    case filelib:is_regular(File) of
        true ->
            {ok, Consult} = file:consult(File),
            {ok, hd(Consult)};
        false -> 
            write_config([{password, z_ids:id(8)}]),
            ensure_config()
    end.


write_config(Config) ->
    {ok, Dev} = file:open(config_file(), [write]),
    ok = file:write(Dev, <<"% This file is automatically generated, do not change while Zotonic is running.",10>>),
    Data = io_lib:format("~p.~n", [Config]),
    ok = file:write(Dev, iolist_to_binary(Data)),
    ok = file:close(Dev).
    

config_file() ->
    filename:join([z_utils:lib_dir(priv), "config"]).
    