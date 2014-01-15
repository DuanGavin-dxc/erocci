%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2013, Jean Parpaillon
%%% 
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%% 
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%% 
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%% 
%%% @doc
%%%
%%% @end
%%% Created :  1 Jul 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_backend_mnesia).
-compile({parse_transform, lager_transform}).

-behaviour(occi_backend).

-include("occi.hrl").

%% occi_backend callbacks
-export([init/1,
	 terminate/1,
	 save/2,
	 find/2]).

-record(state, {}).

%%%===================================================================
%%% occi_backend callbacks
%%%===================================================================
init(_) ->
    mnesia:create_table(occi_collection,
			[{disc_copies, [node()]},
			 {attributes, record_info(fields, occi_collection)}]),
    mnesia:create_table(occi_resource,
		       [{disc_copies, [node()]},
			{attributes, record_info(fields, occi_resource)}]),
    mnesia:create_table(occi_mixin,
		       [{disc_copies, [node()]},
			{attributes, record_info(fields, occi_mixin)}]),
    mnesia:wait_for_tables([occi_resource, occi_category], infinite),
    {ok, #state{}}.

terminate(#state{}) ->
    ok.

save(Obj, State) ->
    mnesia:transaction(save_t(Obj)),
    {{ok, Obj}, State}.

find(#occi_mixin{}=Mixin, #state{}=State) ->
    Res = mnesia:dirty_match_object(Mixin),
    {{ok, Res}, State};
find(#occi_collection{}=Coll, #state{}=State) ->
    Res = mnesia:dirty_match_object(Coll),
    {{ok, Res}, State};
find(_, #state{}=State) ->
    {{error, not_implemented}, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
save_t(#occi_resource{}=Res) ->
    fun() ->
	    mnesia:write(Res),
	    KindId = occi_resource:get_cid(Res),
	    Uri = occi_resource:get_id(Res),
	    case mnesia:wread({occi_collection, KindId}) of
		[#occi_collection{entities=E}=C] ->
		    lager:debug("Update collection: ~p~n", [KindId]),
		    C2 = C#occi_collection{entities=[Uri|E]},
		    mnesia:write(C2);
		_ ->
		    % Create collection on the fly
		    lager:debug("Create collection: ~p~n", [KindId]),
		    mnesia:write(#occi_collection{cid=KindId, entities=[Uri]})
	    end,
	    lists:foreach(fun (#occi_mixin{id=Id}) ->
				  case mnesia:wread({occi_collection, Id}) of
				      [#occi_collection{entities=E2}=C3] ->
					  lager:debug("Update collection: ~p~n", [Id]),
					  C4 = C3#occi_collection{entities=[Uri|E2]},
					  mnesia:write(C4);
				      _ ->
					  lager:debug("Create collection: ~p~n", [Id]),
					  mnesia:write(#occi_collection{cid=Id, entities=[Uri]})
				  end
			  end, occi_resource:get_mixins(Res))
    end;
save_t(#occi_mixin{}=Mixin) ->
    fun () ->
	    mnesia:write(Mixin)
    end;
save_t(#occi_collection{}=Coll) ->
    fun() ->
	    mnesia:write(Coll)
    end.
