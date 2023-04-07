----------------------------------------------------------------
-- NETWORK SURVEY DATABASE
----------------------------------------------------------------
--- Network Survey Database Schema, based upon
--- https://messaging.networksurvey.app

-- Extend the database with TimescaleDB & PostGIS
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS postgis CASCADE;

-- Always use UTC (aka zulu) time internally.
SET timezone TO 'UTC';

CREATE SCHEMA network_survey;

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

CREATE TYPE network_survey.network_type AS ENUM (
       'wifi',
       'ble'
);

----------------------------------------------------------------
-- TABLES
----------------------------------------------------------------

CREATE TABLE network_survey.observers (
    name TEXT NOT NULL PRIMARY KEY, -- this maps to the gnss_message.data.deviceName field
    
    -- fixed position if the object is not moving.  This overrides what the observer reports
    fixed_lat DOUBLE PRECISION,
    fixed_lon DOUBLE PRECISION,
    
    -- Icon attributes defined here: https://flows.nodered.org/node/node-red-contrib-web-worldmap#usage
    --
    -- You can use https://spatialillusions.com/unitgenerator/ to define SIDC codes, but common SIDC codes:
    --  Operations Center : "SDGPUH------"
    --  Good Guy acting as a bad guy in an exercise (aka "faker"): "SKGPU-------"
    --  Green force in an exercise (aka "exercise neutral"): "SLGPU-------"
    --  "Exercise Unknown": "SWGPU-------"
    --  Known foe in an exercise being detected by an observer: "SSGPU-------"
    icon TEXT,      -- font awesome icon name, weather-lite icon, :emoji name:, or https://
    iconColor TEXT, -- Standard CSS colour name or #rrggbb hex value.
    SIDC TEXT,      -- NATO symbology code (can be used instead of icon).
    layer TEXT,     -- specify a layer on the map to add marker to. (default "unknown")
    label TEXT,     -- displays the contents as a permanent label next to the marker, or
    tooltip TEXT    -- displays the contents when you hover over the marker. (Mutually exclusive with label. Label has priority)
);

CREATE TABLE network_survey.devices_of_interest (
    id SERIAL PRIMARY KEY,
    device_type network_survey.network_type NOT NULL,

    -- WiFi attributes
    ssid TEXT,         -- when deice_type = wifi
    bssid TEXT,        -- when deice_type = wifi

    -- bluetooth attributes
    ota_device_name TEXT,
    source_address  TEXT,

    -- describe the device of interest
    description TEXT,
    
    -- Icon attributes defined here: https://flows.nodered.org/node/node-red-contrib-web-worldmap#usage
    --
    -- You can use https://spatialillusions.com/unitgenerator/ to define SIDC codes, but common SIDC codes:
    --  Operations Center : "SDGPUH------"
    --  Good Guy acting as a bad guy in an exercise (aka "faker"): "SKGPU-------"
    --  Green force in an exercise (aka "exercise neutral"): "SLGPU-------"
    --  "Exercise Unknown": "SWGPU-------"
    --  Known foe in an exercise being detected by an observer: "SSGPU-------"
    icon TEXT,      -- font awesome icon name, weather-lite icon, :emoji name:, or https://
    iconColor TEXT, -- Standard CSS colour name or #rrggbb hex value.
    SIDC TEXT,      -- NATO symbology code (can be used instead of icon).
    label TEXT,     -- displays the contents as a permanent label next to the marker, or
    tooltip TEXT,   -- displays the contents when you hover over the marker. (Mutually exclusive with label. Label has priority)
    color TEXT,        -- can set the colour of the polygon or line
    opacity TEXT,      -- the opacity of the line or outline
    fill_color TEXT,   -- can set the fill colour of the polygon.
    fill_opacity TEXT, -- can set the opacity of the polygon fill colour
    weight INTEGER,    -- the width of the line or outline
    ttl INTEGER        -- time to live, how long an individual marker stays on map in seconds. Min = 20s
);

-- an event can be a user-supplied annotation, a notification (such as
-- a detection), an error, etc. that helps describe the events as they
-- occur for historical purposes.  For example, this may be used to
-- describe the STARX, ENDX ad location of an exercise.
CREATE TABLE network_survey.events (
    id SERIAL PRIMARY KEY,
    device_name text NOT NULL, -- who reported the event
    mission_id text NOT NULL,
    "time" timestamp without time zone DEFAULT LOCALTIMESTAMP NOT NULL,
    time_inserted timestamptz NOT NULL DEFAULT NOW(),
    stop_time timestamp without time zone,
    geom GEOMETRY(POLYGON,4326),
    event_type text, -- the type of the event (info, warning, error)
    title text, -- short summary of the event
    description text -- event description in detail
);
CREATE INDEX ix_events_geom ON network_survey.events USING gist(geom);


----------------------------------------------------------------
-- COMPOSITE TYPES: NETWORK SURVEY MESSAGES
----------------------------------------------------------------

CREATE TYPE network_survey.cell_identity_gsm_type AS (
       mcc INT,
       mnc INT,
       lac INT,
       ci INT,
       arfcn INT,
       bsic INT
);

CREATE TYPE network_survey.cell_identity_cdma_type AS (
       sid INT,
       nid INT,
       bsid INT
);

CREATE TYPE network_survey.cell_identity_umts_type AS (
       mcc INT,
       mnc INT,
       lac INT,
       cid INT,
       uarfcn INT,
       psc INT
);

CREATE TYPE network_survey.cell_identity_lte_type AS (
       mcc INT,
       mnc INT,
       tac INT,
       eci INT,
       earfcn INT,
       pci INT
);

CREATE TYPE network_survey.cell_identity_nr_type AS (
       mcc INT,
       mnc INT,
       tac INT,
       nci TEXT,
       narfcn INT,
       pci INT
);


----------------------------------------------------------------
-- TABLES: NETWORK SURVEY MESSAGES
----------------------------------------------------------------

CREATE TABLE network_survey.wifi_beacon_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       source_address TEXT,
       destination_address TEXT,
       bssid TEXT NOT NULL,
       beacon_interval INT,
       service_set_type TEXT,
       ssid TEXT,
       supported_rates TEXT,
       extended_supported_rates TEXT,
       cipher TEXT[],
       akm TEXT[],
       encryption_type  TEXT,
       wps              BOOLEAN,
       channel          SMALLINT,
       frequency        INTEGER,
       signal_strength  FLOAT,
       snr              FLOAT,
       node_type TEXT,
       standard         TEXT
);
CREATE INDEX ix_wifi_beacon_geom ON network_survey.wifi_beacon_observations USING gist(geom);
SELECT create_hypertable('network_survey.wifi_beacon_observations', 'device_time');

CREATE TABLE network_survey.bluetooth_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       source_address  TEXT NOT NULL,
       destination_address TEXT,
       signal_strength FLOAT,
       tx_power FLOAT,
       technology TEXT,
       supported_technologies TEXT,
       ota_device_name TEXT,
       channel INT
);
CREATE INDEX ix_bluetooth_geom ON network_survey.bluetooth_observations USING gist(geom);
SELECT create_hypertable('network_survey.bluetooth_observations', 'device_time');

CREATE TABLE network_survey.gsm_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       mcc INT,
       mnc INT,
       lac INT,
       ci INT,
       arfcn INT NOT NULL,
       bsic INT NOT NULL,
       signal_strength FLOAT NOT NULL,
       ta INT,
       serving_cell BOOLEAN,
       provider TEXT
);
CREATE INDEX ix_gsm_geom ON network_survey.gsm_observations USING gist(geom);
SELECT create_hypertable('network_survey.gsm_observations', 'device_time');

CREATE TABLE network_survey.cdma_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       sid INT,
       nid INT,
       zone INT,
       bsid INT,
       channel INT NOT NULL,
       pn_offset INT NOT NULL,
       signal_strength FLOAT,
       ecio FLOAT NOT NULL,
       serving_cell BOOLEAN,
       provider TEXT
);
CREATE INDEX ix_cdma_geom ON network_survey.cdma_observations USING gist(geom);
SELECT create_hypertable('network_survey.cdma_observations', 'device_time');

CREATE TABLE network_survey.umts_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       mcc INT,
       mnc INT,
       lac INT,
       cid INT,
       uarfcn INT NOT NULL,
       psc INT NOT NULL,
       rscp FLOAT NOT NULL,
       ecno FLOAT,
       signal_strength FLOAT,
       serving_cell BOOLEAN,
       provider TEXT
);
CREATE INDEX ix_umts_geom ON network_survey.umts_observations USING gist(geom);
SELECT create_hypertable('network_survey.umts_observations', 'device_time');

CREATE TABLE network_survey.lte_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       mcc INT,
       mnc INT,
       tac INT,
       eci INT,
       earfcn INT NOT NULL,
       pci INT NOT NULL,
       rsrp FLOAT,
       rsrq FLOAT,
       ta INT,
       signal_strength FLOAT,
       serving_cell BOOLEAN,
       lte_bandwidth TEXT,
       provider TEXT
);
CREATE INDEX ix_lte_geom ON network_survey.lte_observations USING gist(geom);
SELECT create_hypertable('network_survey.lte_observations', 'device_time');

CREATE TABLE network_survey.nr_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       mcc INT,
       mnc INT,
       tac INT,
       nci TEXT,
       narfcn INT NOT NULL,
       pci INT NOT NULL,
       ss_rsrp FLOAT,
       ss_rsrq FLOAT,
       ss_sinr FLOAT,
       csi_rsrp FLOAT,
       csi_rsrq FLOAT,
       csi_sinr FLOAT,
       ta INT,
       serving_cell BOOLEAN,
       provider TEXT
);
CREATE INDEX ix_nr_geom ON network_survey.nr_observations USING gist(geom);
SELECT create_hypertable('network_survey.nr_observations', 'device_time');

CREATE TABLE network_survey.gnss_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       constellation TEXT,
       space_vehicle_id INT,
       carrier_freq_hz INT,
       clock_offset DOUBLE PRECISION,
       used_in_solution BOOLEAN,
       undulation_m FLOAT,
       latitude_std_dev_m FLOAT,
       longitude_std_dev_m FLOAT,
       altitude_std_dev_m FLOAT,
       agc_db FLOAT,
       cn0_db_hz FLOAT,
       hdop FLOAT,
       vdop FLOAT
);
CREATE INDEX ix_gnss_geom ON network_survey.gnss_observations USING gist(geom);
SELECT create_hypertable('network_survey.gnss_observations', 'device_time');

CREATE TABLE network_survey.energy_detection_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       frequency_hz INT NOT NULL,
       bandwidth_hz INT,
       signal_strength FLOAT NOT NULL,
       snr FLOAT,
       time_up TIMESTAMP WITHOUT TIME ZONE,
       duration_sec FLOAT
);
CREATE INDEX ix_energy_detection_geom ON network_survey.energy_detection_observations USING gist(geom);
SELECT create_hypertable('network_survey.energy_detection_observations', 'device_time');

CREATE TABLE network_survey.signal_detection_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       frequency_hz INT NOT NULL,
       bandwidth_hz INT,
       signal_strength FLOAT NOT NULL,
       snr FLOAT,
       time_up TIMESTAMP WITHOUT TIME ZONE,
       duration_sec FLOAT,
       modulation TEXT,
       signal_name TEXT
);
CREATE INDEX ix_signal_detection_geom ON network_survey.signal_detection_observations USING gist(geom);
SELECT create_hypertable('network_survey.signal_detection_observations', 'device_time');

CREATE TABLE network_survey.device_status_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       battery_level_percent INT,
       error_message TEXT
);
CREATE INDEX ix_device_status_geom ON network_survey.device_status_observations USING gist(geom);
SELECT create_hypertable('network_survey.device_status_observations', 'device_time');

CREATE TABLE network_survey.phone_state_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       sim_state TEXT,
       sim_operator TEXT
);
CREATE INDEX ix_phone_state_geom ON network_survey.phone_state_observations USING gist(geom);
SELECT create_hypertable('network_survey.phone_state_observations', 'device_time');

CREATE TABLE network_survey.network_registration_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       domain TEXT,
       access_network_technology TEXT,
       roaming BOOLEAN,
       reject_cause INT,
       cell_identity_gsm network_survey.cell_identity_gsm_type,
       cell_identity_cdma network_survey.cell_identity_cdma_type,
       cell_identity_umts network_survey.cell_identity_umts_type,
       cell_identity_lte network_survey.cell_identity_lte_type,
       cell_identity_nr network_survey.cell_identity_nr_type
);
CREATE INDEX ix_network_registration_geom ON network_survey.network_registration_observations USING gist(geom);
SELECT create_hypertable('network_survey.network_registration_observations', 'device_time');

CREATE TABLE network_survey.gsm_signaling_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       channel_type TEXT NOT NULL,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_gsm_signaling_ota_geom ON network_survey.gsm_signaling_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.gsm_signaling_ota_observations', 'device_time');

CREATE TABLE network_survey.umts_nas_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_umts_nas_ota_geom ON network_survey.umts_nas_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.umts_nas_ota_observations', 'device_time');

CREATE TABLE network_survey.wcdma_rrc_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       channel_type TEXT NOT NULL,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_wcdma_rrc_ota_geom ON network_survey.wcdma_rrc_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.wcdma_rrc_ota_observations', 'device_time');

CREATE TABLE network_survey.lte_rrc_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       channel_type TEXT NOT NULL,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_lte_rrc_ota_geom ON network_survey.lte_rrc_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.lte_rrc_ota_observations', 'device_time');

CREATE TABLE network_survey.lte_nas_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       channel_type TEXT NOT NULL,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_lte_nas_ota_geom ON network_survey.lte_nas_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.lte_nas_ota_observations', 'device_time');

CREATE TABLE network_survey.wifi_ota_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       pcap_record BYTEA NOT NULL
);
CREATE INDEX ix_wifi_ota_geom ON network_survey.wifi_ota_observations USING gist(geom);
SELECT create_hypertable('network_survey.wifi_ota_observations', 'device_time');

CREATE TABLE network_survey.wifi_probe_request_observations (
       device_serial_number TEXT NOT NULL,
       device_name TEXT NOT NULL,
       mission_id TEXT NOT NULL,
       device_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       time_inserted TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
       geom GEOMETRY(POINT,4326),
       altitude FLOAT,
       accuracy INTEGER,
       heading FLOAT,
       pitch FLOAT,
       roll FLOAT,
       field_of_view FLOAT,
       receiver_sensitivity FLOAT,
       source_address  TEXT NOT NULL,
       destination_address TEXT,
       bssid TEXT,
       ssid TEXT,
       channel          SMALLINT,
       frequency        INTEGER,
       signal_strength  FLOAT,
       snr              FLOAT,
       node_type TEXT,
       standard         TEXT
);
CREATE INDEX ix_wifi_probe_request_geom ON network_survey.wifi_probe_request_observations USING gist(geom);
SELECT create_hypertable('network_survey.wifi_probe_request_observations', 'device_time');

----------------------------------------------------------------
-- SAMPLE DATA
----------------------------------------------------------------

-- Fixed positions of participants:
INSERT INTO network_survey.observers (name, fixed_lat, fixed_lon, SIDC) VALUES
       ('OC', 27.941891, -82.45368, 'SDGPUH------')
;

-- Green Forces
INSERT INTO network_survey.observers (name, SIDC) VALUES
       ('green-force-1', 'SLGPU-------'),
       ('green-force-2', 'SLGPU-------'),
       ('green-force-3', 'SLGPU-------')
;

-- "Fakers" aka blue forces acting as bad guys in exercise
INSERT INTO network_survey.observers (name, SIDC) VALUES
       ('red-force-1', 'SKGPU-------'),
       ('red-force-2', 'SKGPU-------'),
       ('red-force-3', 'SKGPU-------')
;

--- Display detections (80211_beacon_message) of targets on the map
INSERT INTO network_survey.devices_of_interest (device_type, ssid) VALUES
       ('wifi', 'red-force-1')
;

--- Display detections (bluetooth_message) of targets on the map
INSERT INTO network_survey.devices_of_interest (device_type, ota_device_name) VALUES
       ('ble', 'red-force-1')
;
