%%%-------------------------------------------------------------------
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
%%% Created : 27 Sep 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_category_mgr).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

%% API
-export([init/0,
	 hash/1]).
-export([find/1,
	 find_all/0,
	 load_schemas/2,
	 register_kind/1,
	 register_mixin/1,
	 register_action/1]).

-define(CAT_TBL, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================
-spec init() -> ok.
init() ->
    lager:info("Starting OCCI categories manager"),
    ?CAT_TBL = ets:new(?CAT_TBL, 
		       [ordered_set, public, {keypos, 2}, named_table, {read_concurrency, true}]),
    ok.

-spec load_schemas(Backend :: atom(), Schemas :: list()) -> ok | {error, term()}.
load_schemas(_, []) ->
    ok;
load_schemas(Backend, [{xml, Path}|Tail]) ->
    case occi_parser_xml:load_extension(Path) of
	{error, parse_error} ->
	    {error, parse_error};
	Ext ->
	    lists:foreach(fun(#occi_kind{id=Id}=Kind) ->
				  register_kind(Kind#occi_kind{location=get_uri(Id)});
			     (#occi_mixin{id=Id}=Mixin) ->
				  register_mixin(Mixin#occi_mixin{location=get_uri(Id)})
			  end,
			  occi_extension:get_categories(Ext)),
	    load_schemas(Backend, Tail)
    end.

register_kind(#occi_kind{id=Id, location=#uri{}=Uri}=Kind) ->
    lager:info("Registering kind: ~p -> ~p~n", [ lager:pr(Id, ?MODULE), lager:pr(Uri, ?MODULE) ]),
    ets:insert(?CAT_TBL, Kind),
    lists:foreach(fun(Action) ->
			  register_action(Action)
		  end,
		  occi_kind:get_actions(Kind)).

register_mixin(#occi_mixin{id=Id, location=Uri}=Mixin) ->
    lager:info("Registering mixin: ~p -> ~p~n", [ lager:pr(Id, ?MODULE), lager:pr(Uri, ?MODULE) ]),
    ets:insert(?CAT_TBL, Mixin),
    lists:foreach(fun(Action) ->
			  register_action(Action)
		  end,
		  occi_mixin:get_actions(Mixin)).

register_action(#occi_action{id=Id}=Action) ->
    lager:info("Registering action: ~p~n", [ lager:pr(Id, ?MODULE) ]),
    ets:insert(?CAT_TBL, Action).

-spec find(occi_category() | uri()) -> [occi_category()].
find(#uri{path=Path}) ->
    case ets:match_object(?CAT_TBL, #occi_kind{location=#uri{path=Path, _='_'}, _='_'}) of
	[] ->
	    ets:match_object(?CAT_TBL, #occi_mixin{location=#uri{path=Path, _='_'}, _='_'});
	Other ->
	    Other
    end;

find(#occi_cid{class=kind}=Cid) ->
    ets:match_object(?CAT_TBL, #occi_kind{id=Cid, _='_'});

find(#occi_cid{class=action}=Cid) ->
    ets:match_object(?CAT_TBL, #occi_action{id=Cid, _='_'});

find(#occi_cid{class=mixin}=Cid) ->
    ets:match_object(?CAT_TBL, #occi_mixin{id=Cid, _='_'});

find(#occi_cid{class='_'}=Cid) ->
    case ets:match_object(?CAT_TBL, #occi_kind{id=Cid, _='_'}) of
	[] ->
	    ets:match_object(?CAT_TBL, #occi_mixin{id=Cid, _='_'});
	Res ->
	    Res
    end;

find(#occi_kind{}=Kind) ->
    ets:match_object(?CAT_TBL, Kind);

find(#occi_mixin{}=Mixin) ->
    ets:match_object(?CAT_TBL, Mixin);

find(#occi_action{}=Action) ->
    ets:match_object(?CAT_TBL, Action).

-spec find_all() -> {[occi_kind()], [occi_mixin()], [occi_action()]}.
find_all() ->
    { find(#occi_kind{_='_'}),
      find(#occi_mixin{_='_'}),
      find(#occi_action{_='_'}) }.

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec hash(occi_cid() -> uri()
%% @end
%%--------------------------------------------------------------------
hash(Cid) ->
    Prefix = occi_config:get(categories_prefix, "/collections"),
    hash1(Cid, Prefix, 0).

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_uri(Id) ->
    {M, F} = occi_config:get(categories_map),
    M:F(Id).

hash1(#occi_cid{term=Term}=Cid, Prefix, 0) ->
    U = #uri{path=lists:flatten(io_lib:format("~s/~s/", [Prefix, atom_to_list(Term)]))},
    case find(U) of
	[] -> U;
	_ ->
	    % Conflict !
	    hash1(Cid, Prefix, 1)
    end;
hash1(#occi_cid{term=Term}=Cid, Prefix, I) ->
    U = #uri{path=lists:flatten(io_lib:format("~s/~s~.b/", [Prefix, atom_to_list(Term), I]))},
    case find(U) of
	[] -> U;
	_ ->
	    % Conflict !
	    hash1(Cid, Prefix, I+1)
    end.    
