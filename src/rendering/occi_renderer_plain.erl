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
%%% Created : 18 Mar 2013 by Jean Parpaillon <jean.parpaillon@free.fr>
%%%-------------------------------------------------------------------
-module(occi_renderer_plain).
-compile({parse_transform, lager_transform}).

-behaviour(occi_renderer).

-include("occi.hrl").

%% API
-export([render/1, parse/1]).

%%%===================================================================
%%% API
%%%===================================================================
render(Category) when is_record(Category, occi_kind); 
		      is_record(Category, occi_mixin);
		      is_record(Category, occi_action) ->
    occi_renderer_text:render(Category, "\n\t");
render(Categories) ->
    lists:map(fun(Cat) -> [<<"Category: ">>, render(Cat), "\n"] end, Categories).

parse(_Bin) ->
    {}.
