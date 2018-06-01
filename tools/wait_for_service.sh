#!/usr/bin/env bash
# We cannot just connect to 127.0.0.1:9042 because Docker is very "smart" and
# exposes ports before the service is ready

if [ "$#" -ne 2 ]; then
    exit "Illegal number of parameters"
fi

CONTAINER="$1"
PORT="$2"
IP=$(/usr/bin/docker inspect -f {{.NetworkSettings.IPAddress}} "$CONTAINER")
echo "$CONTAINER IP is $IP"

tools/wait-for-it.sh -h $IP -p $PORT
