# Phase 2: Data Ingestion (Continuous via Snowpipe)

## Overview

This phase handles the seamless ingestion of simulated IoT sensor data into our Data Warehouse. By taking advantage of an **Event-Driven Architecture**, the process mimics real-world streaming data scenarios typical in IoT operations.

```text
[ Local Machine ]          [ AWS ]                                  [ Snowflake ]
 Phase 1 CSVs     ──>  s3_uploader.py  ──>  Amazon S3 Bucket  ──>  AWS SQS Event  ──>  Snowpipe (Auto-Ingest)  ──>  RAW_SENSOR_DATA Table
```

We specifically use **Snowpipe** (`AUTO_INGEST = TRUE`) because it acts continuously. Instead of a nightly batch load (`COPY INTO`), Snowpipe responds immediately to an S3 event notification as soon as a new file lands, giving us a robust, near-real-time data pipeline.

---

## 💡 Best Practices: S3 to Snowflake Integration (IoT Context)

In building this connection, we follow standard enterprise data engineering practices tailored for IoT/streaming workloads:

1. **Event-Driven Automation (Snowpipe)**: IoT metrics never sleep. Using Snowpipe combined with S3 Event Notifications (SQS) eliminates the need for scheduling cron jobs or using third-party orchestration tools to trigger loads.
2. **Security via Storage Integration**: We avoid hardcoding IAM Access Keys in Snowflake. Instead, we use Snowflake `STORAGE INTEGRATION` utilizing AWS IAM Cross-Account trust relationships (IAM Roles) following the Principle of Least Privilege (e.g., `s3:GetObject`, `s3:ListBucket`).
3. **Decoupled Architecture**: `s3_uploader.py` is entirely unaware of Snowflake. Its only job is to push data to AWS. Snowflake completely abstracts the database loading process away.
4. **Idempotency & Resiliency**: Snowpipe inherently maintains state for 64 days. If the same file is uploaded twice, it won't duplicate the records. We also use `ON_ERROR = 'SKIP_FILE'` (or `CONTINUE`) so malformed payloads don't halt the entire pipeline.

---

## Step-by-Step Configuration Guide

### 1. AWS S3 Infrastructure Setup
Ensure you have an AWS S3 bucket created (e.g., `factory-datalake-1776788959`).
Make sure your local environment has its AWS credentials configured (e.g., via `aws configure` or `~/.aws/credentials`).

### 2. Prepare Snowflake Entities
Run the configuration script to create the Database, Schema, Table, External Stage, and Pipe.

Log in to Snowflake and run the provided SQL definitions from the `snowflake_setup.sql` file. At a high level, it executes:
- `CREATE DATABASE` & `CREATE SCHEMA`
- `CREATE TABLE RAW_SENSOR_DATA`
- `CREATE STAGE` (pointing to your S3 prefix)
- `CREATE PIPE sensor_pipe AUTO_INGEST=TRUE AS COPY INTO...`

### 3. Connect S3 Event to Snowpipe (Crucial Step)
For Snowpipe to be notified, you must connect the Snowflake SQS Queue to your S3 Bucket:
1. In Snowflake, run this command to find the Queue ARN:
   ```sql
   DESC PIPE SMART_FACTORY.RAW.sensor_pipe;
   ```
2. Copy the value in the `notification_channel` column (it should look like `arn:aws:sqs:...`).
3. Open your AWS Console, navigate to your S3 Bucket > **Properties** > **Event Notifications**.
4. Create an event for `All object create events` (`s3:ObjectCreated:*`).
5. Set the Destination as `SQS queue` and enter the `notification_channel` ARN from Snowflake.

### 4. Start Ingestion
With the pipe listening, run the ingestion script. The script drops batches of data into S3 with a slight delay to simulate a real continuous IoT data stream.

```bash
cd 02_data_ingestion
python3 s3_uploader.py --bucket your-s3-bucket-name
```

---

## Verification & Troubleshooting

Once files land in S3, Snowpipe typically processes them in 10-60 seconds. You can verify ingestion directly in Snowflake:

**1. Check total rows loaded:**
```sql
SELECT COUNT(*) FROM SMART_FACTORY.RAW.RAW_SENSOR_DATA;
```

**2. Check Snowpipe status (Is it running? Are there errors?):**
```sql
SELECT SYSTEM$PIPE_STATUS('sensor_pipe');
```

**3. View Snowpipe load history:**
```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.PIPE_USAGE_HISTORY(
  PIPE_NAME => 'sensor_pipe',
  DATE_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
  DATE_RANGE_END => CURRENT_TIMESTAMP()
))
ORDER BY START_TIME DESC;
```

---
**Status**: Ready for Automated Loading 🚀
**Next Phase**: Proceed to `03_data_transformation` to clean and aggregate the raw data using `dbt`.
