#!/bin/bash

# this ensures the mounted volumes used by docker-compose are owned by
# the non-root user otherwise errors occur during container creation
mkdir -p ./mounted_volumes/postgres/postgres-data
mkdir -p ./mounted_volumes/postgres/sql
