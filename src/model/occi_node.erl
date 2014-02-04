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
%%% Created : 24 Jan 2014 by Jean Parpaillon <jean.parpaillon@free.fr>
-module(occi_node).
-compile([{parse_transform, lager_transform}]).

-include("occi.hrl").

-export([new/2,
	 get_type/1,
	 set_type/2,
	 add_children/2,
	 del_children/2,
	 has_children/1,
	 get_parent/1,
	 set_parent/1,
	 get_data/1,
	 set_data/2]).

%%%
%%% API
%%%
-spec new(occi_node_id(), occi_node_type() | occi_object()) -> occi_node().
new(#uri{path=Path}, dir)  ->
    #occi_node{id=#uri{path=Path}, type=dir, data=gb_sets:new()};

new(#uri{path=Path}, #occi_backend{ref=Ref}=Backend)  ->
    #occi_node{id=#uri{path=Path}, objid=Ref, type=mountpoint, data=Backend};

new(#uri{path=Path}, #occi_resource{id=Id}=Data)  ->
    #occi_node{id=#uri{path=Path}, objid=Id, type=occi_resource, data=Data};

new(#uri{path=Path}, #occi_link{id=Id}=Data)  ->
    #occi_node{id=#uri{path=Path}, objid=Id, type=occi_link, data=Data};

new(#uri{path=Path}, #occi_mixin{id=Id}=Data)  ->
    #occi_node{id=#uri{path=Path}, objid=Id, type=occi_user_mixin, data=Data};

new(#uri{path=Path}, #occi_cid{}=Id) ->
    #occi_node{id=#uri{path=Path}, objid=Id, type=occi_collection, data=undefined};

new(#uri{path=Path}, Type) ->
    #occi_node{id=#uri{path=Path}, type=Type}.

-spec get_type(occi_node()) -> occi_node_type().
get_type(#occi_node{type=Type}) ->
    Type.

-spec set_type(occi_node(), occi_node_type()) -> occi_node().
set_type(#occi_node{}=Node, Type) ->
    Node#occi_node{type=Type}.

-spec add_children(occi_node(), [uri()]) -> occi_node().
add_children(#occi_node{type=dir, data=C}=Node, Children) when is_list(Children) ->
    Node#occi_node{data=gb_sets:union(C, gb_sets:from_list(Children))}.

-spec del_children(occi_node(), [uri()]) -> occi_node().
del_children(#occi_node{type=dir, data=C}=Node, Children) when is_list(Children) ->
    Node#occi_node{data=gb_sets:subtract(C, gb_sets:from_list(Children))}.

-spec get_parent(occi_node() | uri() | string()) -> uri().
get_parent(#occi_node{id=#uri{path=Path}}) ->
    get_parent(Path);
get_parent(#uri{path=Path}) -> 
    get_parent(Path);
get_parent(Path) when is_list(Path) ->
    case string:tokens(Path, "/") of
	[_] ->
	    #uri{path="/"};
	L ->
	    #uri{path="/"++string:join(lists:sublist(L, length(L)-1), "/")++"/"}
    end.

-spec set_parent(occi_node()) -> occi_node().
set_parent(#occi_node{id=Id}=Node) ->
    Node#occi_node{parent=get_parent(Id)}.

-spec has_children(occi_node()) -> boolean().
has_children(#occi_node{type=dir, data=Children}) ->
    not gb_sets:is_empty(Children);
has_children(_) ->
    false.

-spec get_data(occi_node()) -> term().
get_data(#occi_node{data=Data}) ->
    Data.

-spec set_data(occi_node(), term()) -> occi_node().
set_data(#occi_node{type=occi_resource}=Node, #occi_resource{}=Data) ->
    Node#occi_node{data=Data};
set_data(#occi_node{type=occi_link}=Node, #occi_link{}=Data) ->
    Node#occi_node{data=Data};
set_data(#occi_node{type=occi_mixin}=Node, #occi_mixin{}=Data) ->
    Node#occi_node{data=Data};
set_data(#occi_node{type=occi_user_mixin}=Node, #occi_mixin{}=Data) ->
    Node#occi_node{data=Data};
set_data(#occi_node{type=Type}, _) ->
    throw({invalid_data_type, Type}).
