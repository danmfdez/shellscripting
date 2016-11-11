#!/bin/sh

SERVICE=$1

ps -ef | grep -v $0 | grep -v grep | grep -q $SERVICE

RESULT=$?

if [ $RESULT != 0 ]; then
        echo "Error, el servicio $SERVICE no esta operativo | $SERVICE=0"
        exit 2
else
        echo "El servicio $SERVICE esta operativo | $SERVICE=1"
        exit 0
fi
