#!/usr/bin/env bash

# Environment variable DB is used by this script.
# If DB is undefined, than this script does nothing.

set -e

TOOLS=`dirname $0`
cd "$TOOLS/.."

# There is one odbc.ini for both mssql and pgsql
# Allows to run both in parallel
function install_odbc_ini
{
# CLIENT OS CONFIGURING STUFF
#
# Be aware, that underscore in TDS_Version is required.
# It can't be just "TDS Version = 7.1".
#
# To check that connection works use:
#
# {ok, Conn} = odbc:connect("DSN=eodbc-mssql;UID=sa;PWD=eodbc_secret+ESL123",[]).
#
# To check that TDS version is correct, use:
#
# odbc:sql_query(Conn, "select cast(1 as bigint)").
#
# It should return:
# {selected,[[]],[{"1"}]}
#
# It should not return:
# {selected,[[]],[{1.0}]}
#
# Be aware, that Driver and Setup values are for Ubuntu.
# CentOS would use different ones.
    cat > ~/.odbc.ini << EOL
[eodbc-mssql]
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so
Setup       = /usr/lib/x86_64-linux-gnu/odbc/libtdsS.so
Server      = 127.0.0.1
Port        = 2433
Database    = eodbc
Username    = sa
Password    = eodbc_secret+ESL123
Charset     = UTF-8
TDS_Version = 7.2
client_charset = UTF-8
EOL
}

# Stores all the data needed by the container
SQL_ROOT_DIR="$(mktemp -d --suffix=eodbc_sql_root)"
echo "SQL_ROOT_DIR is $SQL_ROOT_DIR"

# A directory, that contains resources that needed to bootstrap a container
# i.e. certificates and config files
SQL_TEMP_DIR="$SQL_ROOT_DIR/temp"
mkdir -p "$SQL_TEMP_DIR"

if [ "$DB" = 'mssql' ]; then
    # LICENSE STUFF, IMPORTANT
    #
    # SQL Server Developer edition
    # http://download.microsoft.com/download/4/F/7/4F7E81B0-7CEB-401D-BCFA-BF8BF73D868C/EULAs/License_Dev_Linux.rtf
    #
    # Information from that license:
    # > a. General.
    # > You may install and use copies of the software on any device,
    # > including third party shared devices, to design, develop, test and
    # > demonstrate your programs.
    # > You may not use the software on a device or server in a
    # > production environment.
    #
    # > We collect data about how you interact with this software.
    #   READ MORE...
    #
    # > BENCHMARK TESTING.
    # > You must obtain Microsoft's prior written approval to disclose to
    # > a third party the results of any benchmark test of the software.

    # SCRIPTING STUFF
    docker rm -f eodbc-mssql || echo "Skip removing previous container"
    docker volume rm -f eodbc-mssql-data || echo "Skip removing previous volume"
    #
    # MSSQL wants secure passwords
    # i.e. just "eodbc_secret" would not work.
    #
    # We don't overwrite --entrypoint, but it's possible.
    # It has no '/docker-entrypoint-initdb.d/'-like interface.
    # So we would put schema into some random place and
    # apply it inside 'docker-exec' command.
    #
    # ABOUT VOLUMES
    # Just using /var/opt/mssql volume is not enough.
    # We need mssql-data-volume.
    #
    # Both on Mac and Linux
    # https://github.com/Microsoft/mssql-docker/issues/12
    #
    # Otherwise we get an error in logs
    # Error 87(The parameter is incorrect.) occurred while opening file '/var/opt/mssql/data/master.mdf'
    #
    # Host port is 2433
    # Container port is 1433
    docker run -d -p 2433:1433                           \
               --name=eodbc-mssql                        \
               -e "ACCEPT_EULA=Y"                        \
               -e "SA_PASSWORD=eodbc_secret+ESL123"      \
               -v "$(pwd)/test/mssql.sql:/eodbc.sql:ro"  \
               --health-cmd='/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "eodbc_secret+ESL123" -Q "SELECT 1"' \
               microsoft/mssql-server-linux
    tools/wait_for_healthcheck.sh eodbc-mssql
    tools/wait_for_service.sh eodbc-mssql 1433

    docker exec -it eodbc-mssql \
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "eodbc_secret+ESL123" \
        -Q "CREATE DATABASE eodbc"
    docker exec -it eodbc-mssql \
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "eodbc_secret+ESL123" \
        -i eodbc.sql

    install_odbc_ini

else
    echo "Skip setting up database"
fi
