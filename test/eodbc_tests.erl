-module(eodbc_tests).
-include_lib("eunit/include/eunit.hrl").

% This should fail
basic_test() ->
    application:ensure_all_started(eodbc),
    {ok, Conn} = eodbc:connect("DSN=eodbc-mssql;UID=sa;PWD=eodbc_secret+ESL123",
                               [{return_types,on}, {binary_strings,on}]),
    Result = eodbc:sql_query(Conn, "select 1"),
    ?assertEqual({selected,[{sql_integer,[]}],[{1}]}, Result).
