# 🏭 Smart Factory — IoT & Predictive Maintenance Pipeline

> **End-to-end data engineering pipeline** that simulates factory sensor data, streams it into Snowflake, transforms it with dbt, and surfaces insights via Power BI dashboards.

---

## 🔁 Pipeline Overview

```
Simulator → CSV → AWS S3 → SQS → Snowpipe → RAW Table → dbt → Power BI
```

| Phase | Tool | Output |
|-------|------|--------|
| 1 · Simulate | Python | 50,400 sensor readings (7 days × 5 machines) |
| 2 · Ingest | AWS S3 + Snowpipe | Auto-streamed into `RAW_SENSOR_DATA` |
| 3 · Transform | dbt Core | 4 analytics tables in Snowflake MARTS |
| 4 · Visualize | Power BI Desktop | 2 interactive dashboards |

---

## 📂 Project Structure

```
snowflake-2/
├── 01_data_simulation/     # Sensor data generator (Python)
├── 02_data_ingestion/      # S3 upload + Snowpipe setup scripts
├── 03_data_transformation/ # dbt models (staging → marts)
└── 04_analytics/           # Power BI guides & SQL queries
```

---

## 📊 dbt Models

| Model | Description |
|-------|-------------|
| `stg_sensor_raw` | Cleans & deduplicates raw sensor records |
| `fact_energy_consumption` | Hourly power usage per machine |
| `alert_predictive_maintenance` | Health score alerts by risk level |
| `fact_oee` | Daily OEE = Availability × Performance × Quality |
| `fact_forecasting` | Predicted days to failure via 7-day linear regression |

---

## 📈 Dashboards

### Page 1 — Energy & Operations

<!-- 📸 วางภาพ screenshot ของหน้า Energy & Operations ที่นี่ -->
> _Screenshot placeholder — Energy & Operations dashboard_

---

### Page 3 — OEE & Forecasting

<!-- 📸 วางภาพ screenshot ของหน้า OEE & Forecasting ที่นี่ -->
> _Screenshot placeholder — OEE & Forecasting dashboard_

---

## 🚀 Quick Start

**1. Generate Data**
```bash
cd 01_data_simulation && pip install -r requirements.txt
python sensor_simulator.py
```

**2. Configure Credentials**

Edit `02_data_ingestion/phase2_config.env`:
```env
S3_BUCKET_NAME=your-bucket
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
SNOWFLAKE_ACCOUNT_ID=...
SNOWFLAKE_USER=...
SNOWFLAKE_PASSWORD=...
```

**3. Upload to S3 & Setup Snowpipe**
```bash
cd 02_data_ingestion
python s3_uploader.py
python fix_snowpipe.py     # Creates pipe with correct column mapping
```

**4. Run dbt Transformations**
```bash
cd 03_data_transformation
source .venv/bin/activate
dbt run && dbt test        # PASS=5 WARN=0 ERROR=0
```

**5. Open Power BI** → connect to `SMART_FACTORY.MARTS` → Refresh ✅

---

## 🛠️ Tech Stack

`Python` · `AWS S3` · `AWS SQS` · `Snowflake` · `Snowpipe` · `dbt Core` · `Power BI`

---

## 📝 Notes

- `phase2_config.env` and `profiles.yml` are excluded from Git (`.gitignore`)
- A Snowpipe column-mapping bug was found and fixed via [`fix_snowpipe.py`](02_data_ingestion/fix_snowpipe.py) — see [`02_data_ingestion/README.md`](02_data_ingestion/README.md) for details
- dbt tests: 6/6 passing — not_null, unique, source checks all green

---

*Smart Factory IoT Pipeline · pubpuy · 2025*
