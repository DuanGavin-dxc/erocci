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
%%% Created : 30 Aug 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_link).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

-export([new/0,
	 new/1,
	 new/2,
	 new/4,
	 get_id/1,
	 set_id/2,
	 get_cid/1,
	 set_cid/2,
	 get_mixins/1,
	 add_mixin/2,
	 del_mixin/2,
	 set_attr_value/3,
	 get_attr/2,
	 get_attr_value/2,
	 get_attributes/1,
	 get_target/1,
	 set_target/2,
	 get_target_cid/1,
	 set_target_cid/2,
	 get_source/1,
	 set_source/2,
	 add_prefix/2,
	 rm_prefix/2]).

-export([reset/1]).

-define(CORE_ATTRS, orddict:from_list([{'occi.core.title', occi_attribute:core_title()}])).

%%%
%%% API
%%%
-spec new() -> occi_link().
new() ->
    #occi_link{attributes=?CORE_ATTRS}.

-spec new(Id :: uri(), Kind :: occi_kind()) -> occi_link().
new(#uri{}=Id, #occi_kind{}=Kind) ->
    #occi_link{id=Id, cid=occi_kind:get_id(Kind), 
	       attributes=occi_entity:merge_attrs(Kind, ?CORE_ATTRS)}.

-spec new(occi_kind() | uri()) -> occi_link().
new(#occi_kind{}=Kind) ->
    #occi_link{cid=occi_kind:get_id(Kind), 
	       attributes=occi_entity:merge_attrs(Kind, ?CORE_ATTRS)};
new(#uri{}=Uri) ->
    #occi_link{id=Uri, attributes=?CORE_ATTRS}.

-spec new(uri(), occi_kind(), [{atom(), term}], uri()) -> occi_link().
new(#uri{}=Id, #occi_kind{}=Kind, Attributes, Target) ->
    L = #occi_link{id=Id,
		   cid=occi_kind:get_id(Kind), 
		   attributes=occi_entity:merge_attrs(Kind, ?CORE_ATTRS),
		   target=Target},
    lists:foldl(fun ({Key, Value}, Acc) ->
			occi_link:set_attr_value(Acc, Key, Value)
		end, L, Attributes).

-spec get_id(occi_link()) -> uri().
get_id(#occi_link{id=Id}) ->
    Id.

-spec set_id(occi_link(), uri() | string()) -> occi_link().
set_id(#occi_link{}=L, #uri{}=Id) ->
    L#occi_link{id=Id};
set_id(#occi_link{}=L, Id) ->
    L#occi_link{id=occi_uri:parse(Id)}.

-spec get_source(occi_link()) -> uri().
get_source(#occi_link{source=Src}) ->
    Src.

-spec set_source(occi_link(), uri()) -> occi_link().
set_source(#occi_link{}=Link, #uri{}=Uri) ->
    Link#occi_link{source=Uri};
set_source(#occi_link{}=Link, Uri) ->
    Link#occi_link{source=occi_uri:parse(Uri)}.

-spec get_target(occi_link()) -> uri().
get_target(#occi_link{target=Target}) ->
    Target.

-spec set_target(occi_link(), uri()) -> occi_link().
set_target(#occi_link{}=Link, #uri{}=Uri) ->
    Link#occi_link{target=Uri};
set_target(#occi_link{}=Link, Uri) ->
    Link#occi_link{target=occi_uri:parse(Uri)}.

-spec get_target_cid(occi_link()) -> occi_cid().
get_target_cid(#occi_link{target_cid=C}) ->
    C.

-spec set_target_cid(occi_link(), occi_cid()) -> occi_cid().
set_target_cid(#occi_link{}=L, #occi_cid{}=C) ->
    L#occi_link{target_cid=C}.

-spec get_cid(occi_link()) -> occi_cid().
get_cid(#occi_link{cid=Cid}) ->
    Cid.

-spec set_cid(occi_link(), occi_kind()) -> occi_link().
set_cid(#occi_link{attributes=Attrs}=Res, #occi_kind{id=Cid}=Kind) ->
    Res#occi_link{cid=Cid, attributes=occi_entity:merge_attrs(Kind, Attrs)}.

-spec get_mixins(occi_link()) -> term(). % return set()
get_mixins(#occi_link{mixins=undefined}) ->
    sets:new();
get_mixins(#occi_link{mixins=Mixins}) ->
    Mixins.

-spec add_mixin(occi_link(), occi_mixin()) -> occi_link().
add_mixin(#occi_link{mixins=undefined}=Link, Mixin) ->
    add_mixin(Link#occi_link{mixins=sets:new()}, Mixin);
add_mixin(#occi_link{mixins=Mixins, attributes=Attrs}=Res, #occi_mixin{id=Cid}=Mixin) ->
    Res#occi_link{mixins=sets:add_element(Cid, Mixins), 
		  attributes=occi_entity:merge_attrs(Mixin, Attrs)}.

-spec del_mixin(occi_link(), occi_mixin()) -> occi_link().
del_mixin(#occi_link{mixins=undefined}=Link, _) ->
    Link;
del_mixin(#occi_link{mixins=Mixins, attributes=Attrs}=Res, #occi_mixin{id=Cid}=Mixin) ->
    Res#occi_link{mixins=lists:delete(Cid, Mixins), 
		  attributes=occi_entity:rm_attrs(Mixin, Attrs)}.

-spec set_attr_value(occi_link(), occi_attr_key(), any()) -> occi_link().
set_attr_value(#occi_link{}=Link, Key, Val) when is_list(Key) ->
    set_attr_value(Link, list_to_atom(Key), Val);
set_attr_value(#occi_link{}=Link, 'occi.core.source', Val) ->
    set_source(Link, Val);
set_attr_value(#occi_link{}=Link, 'occi.core.target', Val) ->
    set_target(Link, Val);
set_attr_value(#occi_link{attributes=Attrs}=Link, Key, Val) when is_atom(Key) ->
    case orddict:is_key(Key, Attrs) of
	true ->
	    Attr = orddict:fetch(Key, Attrs),
	    Link#occi_link{attributes=orddict:store(Key, occi_attribute:set_value(Attr, Val), Attrs)};
	false ->
	    {error, {undefined_attribute, Key}}
    end.

-spec get_attr(occi_link(), occi_attr_key()) -> any().
get_attr(#occi_link{id=Val}, 'occi.core.id') ->
    A = occi_attribute:core_id(),
    A#occi_attr{id=Val};
get_attr(#occi_link{source=Val}, 'occi.core.source') ->
    A = occi_attribute:core_src(),
    A#occi_attr{value=Val};
get_attr(#occi_link{target=Val}, 'occi.core.target') ->
    A = occi_attribute:core_target(),
    A#occi_attr{value=Val};
get_attr(#occi_link{attributes=Attr}, Key) ->
    orddict:find(Key, Attr).

get_attr_value(#occi_link{attributes=Attr}, Key) ->
    case orddict:find(Key, Attr) of
	{ok, #occi_attr{value=V}} -> V;
	_ -> throw({error, invalid_attribute})
    end.	    

-spec get_attributes(occi_link()) -> [occi_attr()].
get_attributes(#occi_link{attributes=Attrs}) ->
    orddict:fold(fun (_Key, Value, Acc) -> [Value|Acc] end, [], Attrs).

-spec reset(occi_link()) -> occi_link().
reset(#occi_link{attributes=Attrs}=Link) ->
    Link#occi_link{attributes=orddict:map(fun (_Key, Attr) ->
						  occi_attribute:reset(Attr)
					  end, Attrs)}.

-spec add_prefix(occi_link(), string()) -> occi_link().
add_prefix(Link, Prefix) ->
    L = Link#occi_link{id=occi_uri:add_prefix(Link#occi_link.id, Prefix)},
    L2 = L#occi_link{source=occi_uri:add_prefix(L#occi_link.source, Prefix)},
    L2#occi_link{target=occi_uri:add_prefix(L2#occi_link.target, Prefix)}.

-spec rm_prefix(occi_link(), string()) -> occi_link().
rm_prefix(Link, Prefix) ->
    L = Link#occi_link{id=occi_uri:rm_prefix(Link#occi_link.id, Prefix)},
    L2 = L#occi_link{source=occi_uri:rm_prefix(L#occi_link.source, Prefix)},
    L2#occi_link{target=occi_uri:rm_prefix(L2#occi_link.target, Prefix)}.
