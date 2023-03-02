# ODBC driver for Erlang

It's a fork of a standard odbc application.

[![Build Status](https://travis-ci.org/arcusfelis/eodbc.svg?branch=master)](https://travis-ci.org/arcusfelis/eodbc)

# Why?

Because of incomplete support of nvarchar and nvarbinary in the original
library.

# Build dependencies

- unixodbc
- tdsodbc (if you need to use this library with MSSQL)


# return_types option

Return `{selected, [{Type, ColumnName}], Rows}` instead of `{selected, [ColumnName], Rows}`.

Code:

```erlang
f().
application:start(eodbc).
{ok, Conn} = eodbc:connect("DSN=eodbc-mssql;UID=sa;PWD=eodbc_secret+ESL123", [{return_types, on}]).
eodbc:sql_query(Conn, "drop table example").
eodbc:sql_query(Conn, "create table example(string nvarchar(max))").
eodbc:sql_query(Conn, "insert into example values (CAST('hello' AS VARBINARY(MAX)))").
eodbc:sql_query(Conn, "select * from example").
```

Execution example:

```erlang
20> application:start(eodbc).
{error,{already_started,eodbc}}
21>
21> {ok, Conn}
= eodbc:connect("DSN=eodbc-mssql;UID=sa;PWD=eodbc_secret+ESL123",
[{return_types, on}]).
{ok,<0.184.0>}
22>
22> eodbc:sql_query(Conn, "drop table example").
{updated,undefined}
23>
23> eodbc:sql_query(Conn, "create table example(string nvarchar(max))").
{updated,undefined}
24>
24> eodbc:sql_query(Conn, "insert into example values (CAST('hello' AS
VARBINARY(MAX)))").
{updated,1}
25> eodbc:sql_query(Conn, "select * from example").
{selected,[{{sql_wvarchar,536870911},"string"}],
          [{<<104,101,108,108,111,0>>}]}
```

# Build HEX package

Use rebar3 to compile a HEX package before releasing it to hex.pm:

```
rebar3 compile
rebar3 hex build
```
