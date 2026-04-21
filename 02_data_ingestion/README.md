# Phase 2: Data Ingestion (S3 → Snowflake)

## Overview

Phase 2 moves the sensor data from your local machine to the cloud:

```
Phase 1 (7 batch CSVs)
    ↓
Phase 2: Upload to S3
    ↓ (Snowpipe watches)
    ↓
Snowflake RAW layer
    ↓ (Phase 3)
dbt transformation
```

## Prerequisites

### 1. AWS Setup ✅
- [x] S3 bucket created: `factory-datalake-1776788959`
- [x] IAM role for Snowflake to read S3
- [x] AWS credentials configured locally

### 2. Snowflake Setup ⏳
- [ ] Snowflake account created
- [ ] Admin credentials available

---

## Step-by-Step Execution

### Step 1: Upload CSV Files to S3

Run the upload script:

```bash
cd /workspaces/snowflake-2/02_data_ingestion

python3 s3_uploader.py \
  --bucket factory-datalake-1776788959 \
  --data-path ../01_data_simulation/data/batches
```

**What this does:**
- Reads all 7 batch CSV files from Phase 1
- Uploads to `s3://factory-datalake-1776788959/sensor_raw/`
- Prints confirmation of uploaded files

**Example output:**
```
2026-04-21 16:35:00 - Found 7 batch files to upload
2026-04-21 16:35:00 - Uploading batch_001_20260324_20260325.csv...
2026-04-21 16:35:01 -   ✅ Uploaded to s3://factory-datalake-1776788959/sensor_raw/batch_001_20260324_20260325.csv
...
2026-04-21 16:35:05 - ✅ Upload complete! 7 files ready for Snowpipe ingestion
```

### Step 2: Create Snowflake Infrastructure

**IMPORTANT: Before running the SQL:**

1. Open `snowflake_setup.sql` in this folder
2. Find this line:
   ```sql
   STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::AWS_ACCOUNT_ID:role/SnowflakeS3Role'
   ```
3. Replace with your actual AWS account ID (12 digits)

**Then:**
1. Log in to Snowflake (https://app.snowflake.com)
2. Copy the entire `snowflake_setup.sql` content
3. Paste into a Snowflake worksheet
4. Run all statements (or run individually)

**What this creates:**
```sql
Database: SMART_FACTORY
  ├─ Schema: RAW
  │   └─ Table: RAW_SENSOR_DATA
  ├─ Integration: s3_integration (connects to S3)
  ├─ Stage: sensor_stage (points to S3 path)
  └─ Pipe: sensor_pipe (auto-ingest when files arrive)
```

### Step 3: Verify Data Ingestion

Run this in Snowflake to check if data arrived:

```sql
-- Count rows
SELECT COUNT(*) FROM SMART_FACTORY.RAW.RAW_SENSOR_DATA;
-- Expected: 50,400 rows (after Snowpipe ingests)

-- View first few rows
SELECT * FROM SMART_FACTORY.RAW.RAW_SENSOR_DATA LIMIT 5;

-- Check Snowpipe execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_EXECUTION_STEP('sensor_pipe')) 
ORDER BY PIPE_EXECUTION_STATE_ID DESC LIMIT 10;
```

---

## Troubleshooting

### Issue: "No files found in S3"
```bash
# Verify files were uploaded
aws s3 ls s3://factory-datalake-1776788959/sensor_raw/
```

### Issue: "Snowpipe not ingesting"
- Check S3 integration is created
- Verify AWS IAM role has correct permissions
- Check Snowpipe execution history:
  ```sql
  SELECT * FROM TABLE(INFORMATION_SCHEMA.PIPE_EXECUTION_STEP('sensor_pipe'));
  ```

### Issue: "Failed to create integration"
- Verify AWS account ID is correct
- Check IAM role exists in AWS
- Ensure Snowflake has permissions to assume the role

---

## Architecture After Phase 2

```
LOCAL MACHINE          AWS S3                   SNOWFLAKE
┌──────────────┐      ┌──────────────┐        ┌──────────────┐
│ Phase 1      │      │ sensor_raw/  │        │ SMART_       │
│ 7 batch CSVs │─────▶│ batch_001.csv│─┐      │ FACTORY.RAW  │
│              │      │ batch_002.csv│ └─────▶│ .RAW_SENSOR_ │
│              │      │ ...          │ Pipe   │ DATA         │
└──────────────┘      └──────────────┘        │ (50,400 rows)│
                                               └──────────────┘
```

---

## Next Steps (Phase 3)

Once data is in Snowflake, Phase 3 transforms it using dbt:
- Clean and validate data (STAGING layer)
- Aggregate by hour and equipment (MARTS layer)
- Add business logic and testing

```bash
cd ../03_dbt_project
dbt run   # Generate transformed tables
```

---

## Quick Reference

| File | Purpose |
|------|---------|
| `s3_uploader.py` | Upload Phase 1 CSVs to S3 |
| `snowflake_setup.sql` | Create Snowflake infrastructure |
| `phase2_config.env` | Configuration (bucket name, etc.) |

## Files Generated in Phase 2

```
02_data_ingestion/
├── s3_uploader.py              ← Upload script
├── snowflake_setup.sql         ← Infrastructure SQL
└── README.md                   ← This file
```

---

**Status**: Phase 2 requires manual S3 setup and Snowflake SQL execution
**Next**: Phase 3 - dbt transformation
