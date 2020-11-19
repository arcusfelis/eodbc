-module(eodbc_tests).

-include_lib("eunit/include/eunit.hrl").

simple_test() ->
    Conn = connect_to_database(),
    ?assertEqual({selected,[[]],[{1}]}, eodbc:sql_query(Conn, "SELECT 1")).

create_varbinary_test() ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column varbinary(max))"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values (CAST('test' AS VARBINARY(MAX)))"),
    {selected,["test_column"],[{"74657374"}]} = eodbc:sql_query(Conn, "select test_column from test_types").

create_nvarchar_test() ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column nvarchar(max))"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values ('test')"),
    {selected,["test_column"],[{<<116,0,101,0,115,0,116,0>>}]} = eodbc:sql_query(Conn, "select test_column from test_types").

connect_to_database() ->
    application:start(eodbc),
    {ok, Conn} = eodbc:connect("DSN=eodbc-mssql;UID=sa;PWD=eodbc_secret+ESL123", []),
    Conn.

%% Even and odd lengths handled differenty
varbinary8000_test() ->
    check_varbinary(8000).

varbinary7999_test() ->
    check_varbinary(7999).

varbinary_max_test() ->
    %% Longer than 8000 bytes
    check_varbinary_max(8001),
    check_varbinary_max(8004),
    check_varbinary_max(16000).

nvarchar4000_test() ->
    %% Max size for unicode string is 4000 chars
    check_nvarchar(4000).

nvarchar3999_test() ->
    check_nvarchar(3999).

nvarchar_max_test() ->
    check_nvarchar_max(3999),
    check_nvarchar_max(4000),
    check_nvarchar_max(4001),
    check_nvarchar_max(4002),
    check_nvarchar_max(10000),
    check_nvarchar_max(20000),
    check_nvarchar_max(100000).

varchar8000_test() ->
    check_varchar(8000).

varchar7999_test() ->
    check_varchar(7999).

varchar_max_test() ->
    check_varchar_max(7999),
    check_varchar_max(8000),
    check_varchar_max(8001),
    check_varchar_max(8002),
    check_varchar_max(10000),
    check_varchar_max(20000),
    check_varchar_max(100000).

varlongbinary_test() ->
    check_varlongbinary(<<65,64>>),
    check_varlongbinary(<<65,0,64>>), %% With NULL in the middle
    check_varlongbinary(<<65,64,0>>).

check_varbinary(Times) ->
    Type = "varbinary(" ++ integer_to_list(Times) ++ ")",
    check_varbinary(Times, Type).

check_varbinary_max(Times) ->
    Type = "varbinary(max)",
    check_varbinary(Times, Type).

check_varbinary(Times, Type) ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column " ++ Type ++ ")"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    Value = lists:duplicate(Times, $t),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values (CAST('" ++ Value ++ "' AS " ++ Type ++ "))"),
    ?assertEqual({selected,["test_column"],[{lists:append(lists:duplicate(Times, "74"))}]},
                 eodbc:sql_query(Conn, "select test_column from test_types")).

check_nvarchar(Times) ->
    Type = "nvarchar(" ++ integer_to_list(Times) ++ ")",
    check_nvarchar(Times, Type).

check_nvarchar_max(Times) ->
    Type = "nvarchar(max)",
    check_nvarchar(Times, Type).

check_nvarchar(Times, Type) ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column " ++ Type ++ ")"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    Value = lists:duplicate(Times, $t),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values ('" ++ Value ++ "')"),
    %% utf16 encoded
    Expected = binary:copy(<<116,0>>, Times),
    ?assertEqual({selected,["test_column"],[{Expected}]},
                 eodbc:sql_query(Conn, "select test_column from test_types")).


check_varchar(Times) ->
    Type = "varchar(" ++ integer_to_list(Times) ++ ")",
    check_varchar(Times, Type),
    check_varchar_null(Type).

check_varchar_max(Times) ->
    Type = "varchar(max)",
    check_varchar(Times, Type),
    check_varchar_null(Type).

check_varchar(Times, Type) ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column " ++ Type ++ ")"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    Value = lists:duplicate(Times, $t),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values ('" ++ Value ++ "')"),
    ?assertEqual({selected,["test_column"],[{Value}]},
                 eodbc:sql_query(Conn, "select test_column from test_types")).

check_varlongbinary(Value) when is_binary(Value) ->
    Conn = connect_to_database(),
	Query = "SELECT ?",
	ODBCParams = [{{sql_longvarbinary,byte_size(Value)},[Value]}],
	Result = eodbc:param_query(Conn, Query, ODBCParams, 5000),
    Hex = encode_hex(Value),
    ?assertEqual({selected, [[]], [{Hex}]}, Result).

encode_hex(Bin) ->
    [begin if N < 10 -> 48 + N; true -> 87 + N end end || <<N:4>> <= Bin].

check_varchar_null(Type) ->
    Conn = connect_to_database(),
    eodbc:sql_query(Conn, "drop table test_types"),
    {updated,undefined} = eodbc:sql_query(Conn, "create table test_types(test_column " ++ Type ++ ")"),
    {selected,["test_column"],[]} = eodbc:sql_query(Conn, "select test_column from test_types"),
    {updated,1} = eodbc:sql_query(Conn, "insert into test_types values (NULL)"),
    ?assertEqual({selected,["test_column"],[{null}]},
                 eodbc:sql_query(Conn, "select test_column from test_types")).
