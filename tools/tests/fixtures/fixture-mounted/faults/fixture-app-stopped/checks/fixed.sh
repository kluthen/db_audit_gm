#!/bin/sh
# fixture: never run
if s6-svstat -u /run/service/app | grep -q true; then echo "the service is up"; exit 0; fi
echo "the service is down"; exit 1
