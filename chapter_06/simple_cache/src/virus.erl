-module(virus).
-export([infect/0,
         infect/1,
         infect/2]).


infect(Module) ->
    {Module,Bin,File} = code:get_object_code(Module),
    rpc:multicall(code,load_binary,[Module,File,Bin]).

infect(Node,Module) ->
    {Module,Bin,File} = code:get_object_code(Module),
    rpc:call(Node,code,load_binary,[Module,File,Bin]).

infect() ->
    AllLoaded = code:all_loaded(),
    infect_nodes(AllLoaded).

infect_nodes(AllLoaded) ->
    Nodes = erlang:nodes(),
    infect_nodes(Nodes,AllLoaded).

infect_nodes([Node|Nodes],AllLoaded) ->
    NodeAllLoaded = rpc:call(Node,code,all_loaded,[]),
    load_modules_not_found(Node,AllLoaded,NodeAllLoaded),
    infect_nodes(Nodes,AllLoaded);
infect_nodes([],_) ->
    ok.

load_modules_not_found(Node,[{Module,_}|AllLoaded],NodeAllLoaded) ->
    case lists:keymember(Module,1,NodeAllLoaded) of
        false ->
            infect(Node,Module);
        true ->
            ok
    end,
    load_modules_not_found(Node,AllLoaded,NodeAllLoaded);
load_modules_not_found(_,[],_) ->
    ok.
