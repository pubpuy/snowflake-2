-- Phase 2: Snowflake Infrastructure Setup
-- 
-- This SQL creates the RAW layer in Snowflake where Snowpipe will 
-- automatically ingest data from S3.
--
-- Prerequisites:
--   1. Snowflake account created
--   2. S3 bucket and CSV files uploaded
--   3. Run this script as Snowflake ADMIN
--
-- Steps to run:
--   1. Copy and paste this entire script into Snowflake WebUI
--   2. OR: Use `snowsql` CLI if you have it configured

-- ============================================================================
-- STEP 1: Create Database and Schema
-- ============================================================================

CREATE OR REPLACE DATABASE SMART_FACTORY
  COMMENT = 'Smart Factory IoT & Predictive Maintenance Pipeline';

CREATE OR REPLACE SCHEMA SMART_FACTORY.RAW
  COMMENT = 'Raw sensor data from Phase 1 simulation';

-- ============================================================================
-- STEP 2: Create Raw Sensor Data Table
-- ============================================================================
-- This table structure matches the CSV output from Phase 1

CREATE OR REPLACE TABLE SMART_FACTORY.RAW.RAW_SENSOR_DATA (
    TIMESTAMP TIMESTAMP NOT NULL,
    EQUIPMENT_ID VARCHAR(50) NOT NULL,
    EQUIPMENT_TYPE VARCHAR(50),
    HEALTH_SCORE FLOAT,
    TEMPERATURE FLOAT,
    VIBRATION FLOAT,
    POWER_CONSUMPTION FLOAT,
    IS_ANOMALY INTEGER,
    ANOMALY_REASON VARCHAR(200),
    LOAD_TIMESTAMP TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw sensor readings (50,400 rows over 7 days from 5 equipment units)';

-- ============================================================================
-- STEP 3: Create S3 Storage Integration
-- ============================================================================
-- This allows Snowflake to read from your S3 bucket
--
-- NOTE: Replace with YOUR bucket name!
-- Change: 'arn:aws:s3:::factory-datalake-1776788959'
--         to your actual bucket ARN

CREATE OR REPLACE STORAGE INTEGRATION s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::415699578071:role/SnowflakeS3Role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://factory-datalake-1776788959/sensor_raw/')
  COMMENT = 'Integration to read sensor data from S3';

-- After creating the integration, run this to get the IAM policy:
-- DESC INTEGRATION s3_integration;
-- Then create the IAM role in AWS and attach the policy


-- ============================================================================
-- STEP 4: Create External Stage
-- ============================================================================
-- Points to the S3 location where batch CSV files are stored

CREATE OR REPLACE STAGE sensor_stage
  URL = 's3://factory-datalake-1776788959/sensor_raw/'
  CREDENTIALS = (AWS_KEY_ID = $AWS_KEY_ID AWS_SECRET_KEY = $AWS_SECRET_KEY)
  FILE_FORMAT = (
    TYPE = 'CSV',
    SKIP_HEADER = 1,
    FIELD_DELIMITER = ',',
    RECORD_DELIMITER = '\n',
    SKIP_BLANK_LINES = TRUE,
    NULL_IF = ('NULL', 'null', '')
  )
  COMMENT = 'Stage for sensor data CSV files from S3';


-- ============================================================================
-- STEP 5: Create Snowpipe for Automated Ingestion
-- ============================================================================
-- Snowpipe watches S3 and automatically copies files to the table
-- when they arrive (event-driven, no scheduling needed)

CREATE OR REPLACE PIPE sensor_pipe
  AUTO_INGEST = TRUE
  COMMENT = 'Automatically ingest sensor data when CSV files arrive in S3'
  AS
  COPY INTO SMART_FACTORY.RAW.RAW_SENSOR_DATA (
    TIMESTAMP,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    TEMPERATURE,
    VIBRATION,
    POWER_CONSUMPTION,
    HEALTH_SCORE,
    IS_ANOMALY,
    ANOMALY_REASON
  )
  FROM @sensor_stage
  FILE_FORMAT = (TYPE = 'CSV', SKIP_HEADER = 1)
  ON_ERROR = 'SKIP_FILE';


-- ============================================================================
-- STEP 6: Verify Setup
-- ============================================================================

SELECT COUNT(*) as row_count FROM SMART_FACTORY.RAW.RAW_SENSOR_DATA;

-- Check Snowpipe status (run after files are uploaded):
SELECT SYSTEM$PIPE_STATUS('sensor_pipe');

SELECT *
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  PIPE_NAME => 'SENSOR_PIPE',
  DATE_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
  DATE_RANGE_END => CURRENT_TIMESTAMP()
))
ORDER BY START_TIME DESC;

-- List files in S3 stage (verify connectivity):
LIST @sensor_stage;
