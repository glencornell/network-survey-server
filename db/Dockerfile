FROM timescale/timescaledb-ha:pg15-latest

ADD db.sql /docker-entrypoint-initdb.d

COPY ./config_system.py /etc/pgadmin/config_system.py
