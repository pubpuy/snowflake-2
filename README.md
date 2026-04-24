# Smart Factory IoT & Predictive Maintenance Pipeline

A complete end-to-end data pipeline demonstrating industrial IoT data processing, cloud ingestion, transformation, and analytics.

## 📋 Quick Overview

- **Data Volume**: 50,400 realistic sensor readings over 7 days
- **Equipment**: 5 industrial units with 3 sensors each (temperature, vibration, power)
- **Pipeline**: Simulation → S3 Ingestion → Snowflake → dbt Transformation → Analytics

## 🏗️ Architecture

```
Python Simulator → AWS S3 → Snowflake → dbt → BI Dashboards
  (batch files)   (raw CSV)  (raw tables)  (transformations)
```

## 📂 Project Structure

| Folder | Purpose |
|--------|---------|
| `01_data_simulation/` | Python-based IoT sensor data generation with degradation models |
| `02_data_ingestion/` | AWS S3 upload & Snowflake Snowpipe configuration |
| `03_data_transformation/` | dbt models for data quality & analytics marts |
| `04_analytics/` | SQL queries & BI dashboard definitions |

## 🚀 Quick Start

### Phase 1: Generate Simulated Data
```bash
cd 01_data_simulation
pip install -r requirements.txt
python sensor_simulator.py
```
Creates 7 daily batch files with realistic sensor degradation.

### Phase 2: Upload to S3 & Snowflake
```bash
cd 02_data_ingestion
python s3_uploader.py
# Configure Snowflake credentials from phase2_config.env
```

### Phase 3: Transform with dbt
```bash
cd 03_data_transformation
pip install -r requirements.txt
dbt run
dbt test
```

### Phase 4: Analyze Results
```bash
cd 04_analytics
# Run queries from queries/ folder
# Build dashboards from dashboards/ folder
```

## 🎓 Learning Objectives

- ✅ Design end-to-end data pipelines
- ✅ Generate realistic time-series data
- ✅ Work with cloud platforms (AWS S3, Snowflake)
- ✅ Transform data using dbt & SQL
- ✅ Build analytics dashboards for business insights
- ✅ Implement predictive maintenance monitoring

## 📊 Key Insights

This pipeline demonstrates:
- **Realistic degradation models** - Equipment health metrics decline over time
- **Multi-tenant architecture** - 5 independent equipment units
- **Data quality tests** - dbt tests ensure transformation accuracy
- **Automated ingestion** - Snowpipe loads data without manual intervention
- **Executive dashboards** - Maintenance alerts and energy metrics

## 🔧 Tech Stack

- **Python** - Data generation (Numpy, Pandas)
- **AWS S3** - Cloud storage for raw data
- **Snowflake** - Cloud data warehouse
- **dbt** - Data transformation framework
- **SQL** - Analytics & dashboards

## 📖 Documentation

For detailed phase explanations, see [plan-snowflake-project.prompt.md](plan-snowflake-project.prompt.md)

## 👤 Author

pubpuy

---

**Status**: Educational project for learning modern data engineering practices.
