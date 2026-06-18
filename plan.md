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
  - [x] `fact_oee.sql`: Calculate OEE (Availability × Performance × Quality) per equipment per day.
  - [x] `fact_forecasting.sql`: Predict Days to Failure using 7-day linear health score regression.
- [x] Add dbt data tests to ensure data quality (e.g., no nulls, accepted values).
- [x] Build and run dbt models in the Snowflake `STAGING` and `MARTS` schemas.

## 📌 Phase 4: Analytics & Dashboards (🔄 In Progress)
**Objective:** Visualize the transformed data to provide actionable business insights.
- [x] Write analytical SQL queries to extract metrics (`04_analytics/queries/energy_metrics.sql` and `maintenance_metrics.sql`).
- [x] Document data dictionaries for business users (`04_analytics/data_dictionaries/fact_energy_consumption.md` and `alert_predictive_maintenance.md`).
- [x] Create connection and dashboard documentation for AWS QuickSight ([quicksight_integration_guide.md](file:///home/vscode/.gemini/antigravity-cli/brain/47e2103b-40fa-4d48-a7dd-964795c5132d/quicksight_integration_guide.md)).
- [x] Configure and connect Snowflake to Microsoft Power BI Desktop ([powerbi_integration_guide.md](file:///home/vscode/.gemini/antigravity-cli/brain/47e2103b-40fa-4d48-a7dd-964795c5132d/powerbi_integration_guide.md)).
  - [x] Resolve metadata `null to Text` connector bug using custom SQL Native Queries.
  - [x] Disable Power BI native query approval security block (`EvaluateNativeQueryUnpermitted`).
- [x] **Page 1 — Energy & Operations**: Donut chart, Line chart, KPI Cards, Bar chart (Equipment Ranking), Scatter plot (Temp vs Power), Slicers.
- [ ] **Page 2 — Maintenance Alerts**: Alert table with conditional row color, Health trend line chart, Days-to-failure bar chart, Slicers. *(Skipped — lower priority)*
- [ ] **Page 3 — OEE & Forecasting**: OEE KPI cards, OEE by equipment bar chart, OEE trend line chart, Failure forecasting table. *(In Progress — see `04_analytics/dashboards/oee_forecasting.md`)*
  - [x] Import `FACT_OEE` and `FACT_FORECASTING` via Native Query into Power BI.
  - [ ] Create DAX measures (Avg OEE, Avg Availability, Avg Performance, Avg Quality, etc.).
  - [ ] Build all visuals and slicers for Page 3.
- [ ] **Page 0 — Executive Overview**: Cross-page KPI summary, factory health status badge. *(Planned — build last)*

---

### 💡 Current Status
Core pipeline completed. Extended with OEE & Forecasting analytics layer.
1. **Data Generation & Ingestion (Phases 1 & 2)**: Simulator generated 7 days of sensor readings, ingested in real-time via AWS S3 and Snowflake Snowpipe.
2. **dbt Transformation (Phase 3)**: 4 models total — raw records cleaned and transformed into hourly energy metrics, risk alerts, daily OEE scores, and equipment failure forecasts. Passed 6/6 data tests.
3. **Analytics & BI Dashboards (Phase 4)**: Page 1 (Energy) complete. Page 3 (OEE & Forecasting) in progress — dbt models built and loaded into Snowflake, Power BI import guide created.

**Current Action:** Building Power BI Page 3 — OEE & Forecasting dashboard.