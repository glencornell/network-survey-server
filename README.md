# MQTT + Node-red + Postgresql + TimescaleDb + PostGIS = Network Survey Server

set up your own locally hosted server for the network survey android app

## Introduction

This project is a locally-hosted server for the [Android Network Survey](https://github.com/christianrowlands/android-network-survey) application.  The server consists at its core the mosquitto MQTT broker, Node-Red for ETL, and PostGIS as a database.  The API for the application is maintained in the [Network Survey Messaging](https://github.com/christianrowlands/network-survey-messaging) github repo.

## Getting help

The Makefile should be the single point of entry for the environment.
It should ensure that the host has all of the depedencies resolved and
allow you to start and stop the application with minimal manual
procedures.  To get help, type the following:

```bash
make help
```

## Starting environment

You first need to configure the system for your environment.  First
copy the default configuration file `.defconfig` to `.config` and
tailor it to your specific environment.

Persisted volumes are locally stored under the directory `mounted_volumes`.

The `makefile` performs all of this initial host setup as a
convenience for you.

To run the service in the background:
```bash
make start
```

To stop the service, run
```bash
make stop
```

To remove the docker images and remove the persistent storage, type:
```bash
make clean
```

## Running Clients

Install the Android [network survey](https://play.google.com/store/apps/details?id=com.craxiom.networksurvey&gl=US) app on your phone.  Configure the app to use the mqtt broker and port number in the docker container and then connect.  The application should start to populate the database immediately.

## Roadmap

### General
- [ ] Improve security (enclose system in a VPN or add TLS with authentication)
- [ ] create an API gateway for UI
- [ ] create flows that uses n-point trilateration (or multilateration) based upon RSSI to precisely locate transmitters (namely, base stations & access points) & store results in new table
- [ ] decode and process wifi packet over the air (OTA) messages
- [ ] ingest pcap, wigle csv, & kismetdb files.
### Database
- [ ] generate sql schema from asyncapi
- [x] use spatial index for geometries in postgis (lat/lon/alt)
- [x] use temporal index for timestamps (using timescaledb)
### MQTT
- [ ] use TLS
- [ ] use basic authentication
### ETL
- [ ] consider switching from node-red to nifi or other ETL platform
