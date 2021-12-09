#!/bin/bash

if [ $# -lt 1 ]; then
  echo "usage: $0 <programName>"
  exit 1
fi

curl -u dummy:dummy --silent --no-buffer \
  http://localhost:9001/RPC2 --data "<?xml version=\"1.0\"?><methodCall><methodName>supervisor.getProcessInfo</methodName><params><param><value>$1</value></param></params></methodCall>" |
  grep -q "STARTING\|RUNNING"
