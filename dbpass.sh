#!/bin/bash
docker logs percona 2>&1 | grep PASSWORD | sed -e 's/GENERATED ROOT PASSWORD\: //g' | awk 'NR==1 { printf("%s", $0); next } { printf("\n%s", $0) }' | pbcopy
