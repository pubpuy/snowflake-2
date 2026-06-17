# 📝 Project Plan & Progress: Smart Factory IoT & Predictive Maintenance

This document tracks our current progress and outlines the remaining steps for our end-to-end data pipeline project.

## 📌 Phase 1: Data Simulation (✅ Completed)
**Objective:** Generate realistic simulated IoT sensor data.
- [x] Create configuration for equipment (`01_data_simulation/config.yml`).
- [x] Write Python simulator (`01_data_simulation/sensor_simulator.py`).
- [x] Generate 7 days of time-series sensor data (50,400 rows).
- [x] Output data as batch CSV files in `01_data_simulation/data/batches/`.

## 📌 Phase 2: Data Ingestion (✅ Completed)
**Objective:** Automate the ingestion of raw data from AWS S3 into Snowflake.
- [x] Setup AWS S3 Bucket (`factory-datalake-1776788959`).
- [x] Verify AWS CLI connection and upload batch CSVs to S3.
- [x] Create Snowflake Database (`SMART_FACTORY`) and Schema (`RAW`).
- [x] Create the target table (`RAW_SENSOR_DATA`) in Snowflake.
- [x] Create AWS IAM Role (`Snowflake_S3_Integration_Role`) for secure access.
- [x] Configure Snowflake `STORAGE INTEGRATION` and update AWS Trust Policy.
- [x] Create Snowflake `STAGE` (`sensor_stage`) linking to the S3 bucket.
- [x] Create `PIPE` (`sensor_pipe`) with `AUTO_INGEST = TRUE`.
- [x] (Automated via Snowflake) Integrate AWS SQS for event-driven real-time loading.

## 📌 Phase 3: Data Transformation / dbt (✅ Completed)
**Objective:** Clean, model, and aggregate the raw data into business-ready tables using dbt (data build tool).
- [x] Initialize the dbt project and configure the connection to Snowflake (`profiles.yml`).
- [x] Define **Staging Models** (`stg_sensor_raw.sql`) to clean and deduplicate raw data.
- [x] Define **Marts/Business Models**:
  - [x] `fact_energy_consumption.sql`: Aggregate data by hour for energy monitoring.
  - [x] `alert_predictive_maintenance.sql`: Filter and categorize machine health alerts.
- [x] Add dbt data tests to ensure data quality (e.g., no nulls, accepted values).
- [x] Build and run dbt models in the Snowflake `STAGING` and `MARTS` schemas.

## 📌 Phase 4: Analytics & Dashboards (⏳ In Progress)
**Objective:** Visualize the transformed data to provide actionable business insights.
- [x] Write analytical SQL queries to extract metrics (`04_analytics/queries/energy_metrics.sql` and `maintenance_metrics.sql`).
- [x] Document data dictionaries for business users (`04_analytics/data_dictionaries/fact_energy_consumption.md` and `alert_predictive_maintenance.md`).
- [ ] Create dashboard layouts or connect a BI tool (AWS QuickSight / Tableau / Metabase) to Snowflake.
- [ ] Monitor predictive maintenance alerts and energy operations.

---

### 💡 Current Status
We have successfully completed all coding and data engineering work!
1. **Data Generation & Ingestion (Phases 1 & 2)** are complete and data has landed.
2. **dbt Transformation (Phase 3)** is complete, models compiled successfully, and 6/6 tests passed.
3. **Analytics Prep (Phase 4)**: The SQL query library and data dictionaries have been completed and verified by running python queries directly against Snowflake.

**Current Action:** Taking a break as requested by the user. Next time, we can connect a BI tool or build visual dashboard mockups to wrap up Phase 4!