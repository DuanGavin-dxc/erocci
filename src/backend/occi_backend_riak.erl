%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2013, Jean Parpaillon
%%% @doc
%%%
%%% @end
%%% Created :  1 Jul 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_backend_riak).
-compile({parse_transform, lager_transform}).

-behaviour(occi_backend).

-include("occi.hrl").

%% occi_backend callbacks
-export([init/1,
	 terminate/1,
	 save/2,
	 get/3,
	 find/3,
	 update/3,
	 delete/3]).
-export([validate_cfg/1]).

-record(state, {pb :: pid()}).

%%%===================================================================
%%% occi_backend callbacks
%%%===================================================================
init(Opts) ->
    {ip, Node} = lists:keyfind(ip, 1, Opts),
    {port, Port} = lists:keyfind(port, 1, Opts),
    case riakc_pb_socket:start_link(Node, Port) of
	{ok, Pid} -> 
	    {ok, #state{pb=Pid}};
	{error, Error} ->
	    lager:error("Error starting riak client: ~p~n", [Error]),
	    {error, Error}
    end.

terminate(#state{pb=Pid}) ->
    riakc_pb_socket:stop(Pid).

save(Obj, #state{pb=Pid}=State) ->
    RObj = riakc_obj:new(occi_renderer_json:render(occi_entity:get_cid(Obj)),
			 occi_entity:get_id(Obj),
			 occi_renderer_json:render(Obj)),
    riakc_pb_socket:put(Pid, RObj),
    Id = riakc_obj:key(RObj),
    {{ok, Id}, State}.

get(CatId, Id, #state{pb=Pid}=State) ->
    {ok, Obj} = riakc_pb_socket:get(Pid,
				    occi_tools:to_binary(CatId),
				    Id),
    Resource = occi_tools:from_json(riakc_obj:get_value(Obj)),
    {{ok, Resource}, State}.

find(_CatId, _Filter, State) ->
    % Not implemented yet
    {{ok, []}, State}.

update(CatId, Entity, #state{pb=Pid}=State) ->
    % Update looks the same as create as there is no difference
    % between riak key and entity id
    Obj = riakc_obj:new(occi_tools:to_binary(CatId),
			occi_tools:get_entity_id(Entity),
			occi_tools:to_json(Entity)),
    riakc_pb_socket:put(Pid, Obj),
    {ok, State}.

delete(_CatId,_Id, State) ->
    {ok, State}.

validate_cfg(Opts) ->
    Address = case lists:keyfind(ip, 1, Opts) of
		  false ->
		      {127,0,0,1};
		  {ip, Bin} ->
		      Str = binary_to_list(Bin),
		      case inet_parse:address(Str) of
			  {ok, _Ip} -> Str;
			  {error, einval} -> 
			      lager:error("Invalid address: ~p~n", [Str]),
			      throw(einval)
		      end
	      end,
    Port = case lists:keyfind(port, 1, Opts) of
	       false ->
		   8087;
	       {port, I} -> I
	   end,
    [{ip, Address}, {port, Port}].

%%%===================================================================
%%% Internal functions
%%%===================================================================
