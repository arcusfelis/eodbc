#!/usr/bin/env bash

# Environment variable DB is used by this script.
# If DB is undefined, than this script does nothing.

set -e

TOOLS=`dirname $0`


MIM_PRIV_DIR=${BASE}/priv

DB_CONF_DIR=${BASE}/${TOOLS}/db_configs/$DB

SQL_TEMP_DIR=/tmp/sql

MYSQL_DIR=/etc/mysql/conf.d

PGSQL_ODBC_CERT_DIR=~/.postgresql

SSLDIR=${BASE}/${TOOLS}/ssl

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
Port        = 1433
Database    = eodbc
Username    = sa
Password    = eodbc_secret+ESL123
Charset     = UTF-8
TDS_Version = 7.2
client_charset = UTF-8

[eodbc-pgsql]
Driver               = PostgreSQL Unicode
ServerName           = localhost
Port                 = 5432
Database             = eodbc
Username             = eodbc
Password             = eodbc_secret
sslmode              = verify-full
Protocol             = 9.3.5
Debug                = 1
ByteaAsLongVarBinary = 1
EOL
}

if [ "$DB" = 'mysql' ]; then
    echo "Configuring mysql"
    # TODO We should not use sudo
    sudo -n service mysql stop || echo "Failed to stop mysql"
    mkdir -p ${SQL_TEMP_DIR}
    cp ${SSLDIR}/fake_cert.pem ${SQL_TEMP_DIR}/.
    openssl rsa -in ${SSLDIR}/fake_key.pem -out ${SQL_TEMP_DIR}/fake_key.pem
    # mysql_native_password is needed until mysql-otp implements caching-sha2-password
    # https://github.com/mysql-otp/mysql-otp/issues/83
    docker run -d \
        -e SQL_TEMP_DIR=${SQL_TEMP_DIR} \
        -e MYSQL_ROOT_PASSWORD=secret \
        -e MYSQL_DATABASE=eodbc \
        -e MYSQL_USER=eodbc \
        -e MYSQL_PASSWORD=eodbc_secret \
        -v ${DB_CONF_DIR}/mysql.cnf:${MYSQL_DIR}/mysql.cnf:ro \
        -v ${MIM_PRIV_DIR}/mysql.sql:/docker-entrypoint-initdb.d/mysql.sql:ro \
        -v ${BASE}/${TOOLS}/docker-setup-mysql.sh:/docker-entrypoint-initdb.d/docker-setup-mysql.sh \
        -v ${SQL_TEMP_DIR}:${SQL_TEMP_DIR} \
        --health-cmd='mysqladmin ping --silent' \
        -p 3306:3306 --name=eodbc-mysql \
        mysql --default-authentication-plugin=mysql_native_password

elif [ "$DB" = 'pgsql' ]; then
    # If you see "certificate verify failed" error in Mongoose logs, try:
    # Inside tools/ssl/:
    # make clean && make
    # Than rerun the script to create a new docker container.
    echo "Configuring postgres with SSL"
    sudo service postgresql stop || echo "Failed to stop psql"
    mkdir -p ${SQL_TEMP_DIR}
    cp ${SSLDIR}/fake_cert.pem ${SQL_TEMP_DIR}/.
    cp ${SSLDIR}/fake_key.pem ${SQL_TEMP_DIR}/.
    cp ${DB_CONF_DIR}/postgresql.conf ${SQL_TEMP_DIR}/.
    cp ${DB_CONF_DIR}/pg_hba.conf ${SQL_TEMP_DIR}/.
    cp ${MIM_PRIV_DIR}/pg.sql ${SQL_TEMP_DIR}/.
    docker run -d \
           -e SQL_TEMP_DIR=${SQL_TEMP_DIR} \
           -v ${SQL_TEMP_DIR}:${SQL_TEMP_DIR} \
           -v ${BASE}/${TOOLS}/docker-setup-postgres.sh:/docker-entrypoint-initdb.d/docker-setup-postgres.sh \
           -p 5432:5432 --name=eodbc-pgsql postgres
    mkdir -p ${PGSQL_ODBC_CERT_DIR} || echo "PGSQL odbc cert dir already exists"
    cp ${SSLDIR}/ca/cacert.pem ${PGSQL_ODBC_CERT_DIR}/root.crt
    install_odbc_ini

elif [ "$DB" = 'mssql' ]; then
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
    #
    # MSSQL wants secure passwords
    # i.e. just "eodbc_secret" would not work.
    #
    # We don't overwrite --entrypoint, but it's possible.
    # It has no '/docker-entrypoint-initdb.d/'-like interface.
    # So we would put schema into some random place and
    # apply it inside 'docker-exec' command.
    docker run -d -p 1433:1433                                  \
               --name=eodbc-mssql                            \
               -e "ACCEPT_EULA=Y"                               \
               -e "SA_PASSWORD=eodbc_secret+ESL123"        \
               -v "$(pwd)/priv/mssql2012.sql:/eodbc.sql:ro"  \
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
