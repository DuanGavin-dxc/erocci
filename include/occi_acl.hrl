%%% @author Jean Parpaillon <jean.parpaillon@free.fr>
%%% @copyright (C) 2014, Jean Parpaillon
%%% @doc Created from https://github.com/dizz/occi-grammar/blob/master/occi-antlr-grammar/Occi.g
%%%
%%% @end
%%% Created : 15 May 2014 by Jean Parpaillon <jean.parpaillon@free.fr>
-type(acl() :: {acl_policy(), acl_op(), acl_node(), acl_user()}).

-type(acl_policy() :: allow | deny).
-type(acl_op() :: create | read | update | {action, binary() } | delete | '_').
-type(acl_node() :: capabilities | term() | '_').
-type(acl_url() :: binary()).
-type(acl_user() :: anonymous | authenticated | admin | owner | '_').
