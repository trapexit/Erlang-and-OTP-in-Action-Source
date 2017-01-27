-module(simple_cache).

-export([insert/2, lookup/1, delete/1]).

insert(Key, Value) ->
    case sc_store:lookup(Key) of
        {ok, Pid} ->
            sc_element:replace(Pid, Value);
        {error, _} ->
            {ok, Pid} = sc_element:create(Value),
            sc_store:insert(Key, Pid)
    end.

lookup(Key) ->
    try
        {ok, Pid} = '_lookup'(Key),
        {ok, Value} = sc_element:fetch(Pid),
        {ok, Value}
    catch
        _Class:_Exception ->
            {error, not_found}
    end.

delete(Key) ->
    case sc_store:lookup(Key) of
        {ok, Pid} ->
            sc_element:delete(Pid);
        {error, _Reason} ->
            ok
    end.


%%%%%%
%% PRIVATE
%%%%%%

'_find_remote_lookup_result'([{ok,_}=RV|_Tail]) ->
    RV;
'_find_remote_lookup_result'([_|Tail]) ->
    '_find_remote_lookup_result'(Tail);
'_find_remote_lookup_result'([]) ->
    {error,not_found}.

'_remote_lookup'(Key) ->
    {ResL,_BadNodes} = rpc:multicall(sc_store,lookup,[Key]),
    '_find_remote_lookup_result'(ResL).

'_monitor_loop'(Pid) ->
    receive
        {'DOWN',_Ref,process,Pid,_Info} ->
            sc_store:delete(Pid);
        _ ->
            '_monitor_loop'(Pid)
    end

'_monitor_fun'(Pid) ->
    fun() ->
            erlang:monitor(process,Pid),
            '_monitor_loop'(Pid)
    end.

'_spawn_monitor'(Pid) ->
    Fun = '_monitor_fun'(Pid),
    erlang:spawn(Fun).

'_lookup'(Key) ->
    case sc_store:lookup(Key) of
        {ok,Pid} ->
            {ok,Pid};
        {error,not_found} ->
            case '_remote_lookup'(Key) of
                {ok,Pid} ->
                    %% Cache lookup locally
                    sc_store:insert(Key,Pid),
                    '_spawn_monitor'(Pid),
                    {ok,Pid};
                {error,Reason} ->
                    {error,Reason}
            end
    end.
