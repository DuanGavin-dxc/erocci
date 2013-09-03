%%%-------------------------------------------------------------------
%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2013, Jean Parpaillon
%%% @doc
%%%
%%% @end
%%% Created : 18 Mar 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_renderer_text).
-compile({parse_transform, lager_transform}).

-include("occi.hrl").

%% API
-export([render/2]).
-export([join/2]).

%%%===================================================================
%%% API
%%%===================================================================
render(#occi_kind{}=Kind, Sep) ->
    join(
      join([ render_cid(Kind#occi_kind.id, Sep),
	     render_kv(<<"title">>, [Kind#occi_kind.title]),
	     render_kv(<<"rel">>, lists:map(fun(X) -> render_rel(X) end, Kind#occi_kind.rel)),
	     render_kv(<<"attributes">>, lists:map(fun(X) -> render_attr_spec(X) end, Kind#occi_kind.attributes)),
	     render_kv(<<"actions">>, lists:map(fun(X) -> render_action_spec(X) end, Kind#occi_kind.actions)),
	     render_kv(<<"location">>, [Kind#occi_kind.location])], 
	   <<"; ">>), 
      Sep);
render(#occi_mixin{}=Mixin, Sep) ->
    join(
      join([ render_cid(Mixin#occi_mixin.id, Sep),
	     render_kv(<<"title">>, [Mixin#occi_mixin.title]),
	     render_kv(<<"attributes">>, lists:map(fun(X) -> render_attr_spec(X) end, Mixin#occi_mixin.attributes)),
	     render_kv(<<"actions">>, lists:map(fun(X) -> render_action_spec(X) end, Mixin#occi_mixin.actions)),
	     render_kv(<<"location">>, [Mixin#occi_mixin.location])], 
	   <<"; ">>), 
      Sep);
render(#occi_action{}=Action, Sep) ->
    join(
      join([ render_cid(Action#occi_action.id, Sep),
	     render_kv(<<"title">>, [Action#occi_action.title]),
	     render_kv(<<"attributes">>, lists:map(fun(X) -> render_attr_spec(X) end, Action#occi_action.attributes))],
	   <<"; ">>),
      Sep);
render(O, _Sep) ->
    lager:error("Invalid value: ~p~n", [O]),
    throw({error, {occi_syntax, "invalid value"}}).

render_cid(#occi_cid{scheme=Scheme}=Cid, Sep) when is_atom(Scheme) ->
    render_cid(Cid#occi_cid{scheme=atom_to_list(Scheme)}, Sep);
render_cid(#occi_cid{}=Cid, Sep) ->
    join(
      join([ [atom_to_list(Cid#occi_cid.term)],
	     render_kv(<<"scheme">>, [Cid#occi_cid.scheme]),
	     render_kv(<<"class">>, [atom_to_list(Cid#occi_cid.class)]) 
	   ], 
	   <<"; ">>), 
      Sep).

render_attr_spec({K, [], _F}) ->
    atom_to_list(K);
render_attr_spec({K, L, _F}) ->
    [ atom_to_list(K), <<"{">>, join(to_list(L), ","), <<"}">> ];
render_attr_spec({K, _F}) ->
    atom_to_list(K).

render_action_spec({Scheme, Term, _Desc, _Attrs}) ->
    [ Scheme, atom_to_list(Term) ].

render_rel({Scheme, Term}) when is_atom(Scheme) ->
    render_rel({atom_to_list(Scheme), Term});
render_rel({Scheme, Term}) ->
    [ Scheme, atom_to_list(Term) ].

render_kv(_Key, undefined) ->
    [];
render_kv(_Key, <<>>) ->
    [];
render_kv(_Key, []) ->
    [];
render_kv(Key, Values) ->
    [Key, "=\"", join(to_list(Values), " "), "\""].

join(L, Sep) ->
    join(L, [], Sep).

join([], Acc, _Sep) ->
    lists:reverse(Acc);
join([H|[]], Acc, _Sep) ->
    lists:reverse([H|Acc]);
join([H, []|T], Acc, Sep) ->
    join([H|T], Acc, Sep);
join([H|T], Acc, Sep) ->
    join(T, [[H, Sep]|Acc], Sep).

to_list(L) ->
    lists:map(fun(X) when is_atom(X) ->
		      atom_to_list(X);
		 (X) -> X end, L).
