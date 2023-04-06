FROM postgis/postgis
#RUN apt update && apt install htop pgtop -y
ADD db.sql /docker-entrypoint-initdb.d

COPY ./config_system.py /etc/pgadmin/config_system.py
