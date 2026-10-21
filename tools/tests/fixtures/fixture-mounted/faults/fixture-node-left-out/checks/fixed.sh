#!/bin/sh
# fixture: never run
test -s /opt/gm/node-health/node.conf && { echo "the node has its node-health config"; exit 0; }
echo "the node has no node-health config"; exit 1
