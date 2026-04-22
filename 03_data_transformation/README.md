# Phase 3: Data Transformation (dbt)

This folder contains the dbt project for transforming raw sensor data from Snowflake into business-ready analytics tables.

## 📁 Directory Structure

```
03_data_transformation/
├── models/
│   ├── staging/           # Data cleaning & preparation layer
│   │   └── stg_sensor_raw.sql
│   └── marts/             # Business-ready aggregate tables
│       ├── fact_energy_consumption.sql
│       └── alert_predictive_maintenance.sql
├── tests/                 # Data quality tests
├── macros/                # Reusable SQL functions
├── seeds/                 # Static reference data (if any)
├── dbt_project.yml        # dbt project configuration
├── profiles.yml           # Snowflake connection settings
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites
- dbt installed: `pip install -r requirements.txt`
- Snowflake connection configured in `profiles.yml`
- Phase 2 (Data Ingestion) completed - data in `SMART_FACTORY.RAW.RAW_SENSOR_DATA`

### Setup

1. **Update profiles.yml** with your Snowflake credentials:
   ```bash
   nano profiles.yml
   # Replace:
   # - <your-snowflake-account-id>
   # - <your-snowflake-user>
   # - <your-snowflake-password>
   ```

2. **Install dbt dependencies** (if any external packages are used):
   ```bash
   dbt deps
   ```

3. **Parse the project** (syntax validation):
   ```bash
   dbt parse
   ```

### Running Transformations

```bash
# Build all models (create staging views + mart tables)
dbt run

# Run data quality tests
dbt test

# Generate documentation
dbt docs generate

# View documentation in browser
dbt docs serve
```

## 📊 Models Overview

### Staging Layer (`models/staging/`)

**stg_sensor_raw.sql**
- Input: `SMART_FACTORY.RAW.RAW_SENSOR_DATA` (raw CSV)
- Output: `SMART_FACTORY.STAGING.STG_SENSOR_RAW` (view)
- Transformations:
  - Deduplicate records
  - Validate sensor ranges
  - Create surrogate keys
  - Add data quality flags

### Marts Layer (`models/marts/`)

**fact_energy_consumption.sql**
- Input: `STG_SENSOR_RAW`
- Output: `SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION` (table)
- Grain: One row per equipment per hour
- Metrics: Hourly energy, average temperature, max vibration
- Use case: Power trend analysis, equipment efficiency

**alert_predictive_maintenance.sql**
- Input: `STG_SENSOR_RAW`
- Output: `SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE` (table)
- Metrics: Maintenance alerts, health warnings
- Use case: Predictive maintenance dashboards

## 🧪 Testing

dbt includes built-in tests for data quality:

```bash
# Run all tests
dbt test

# Run tests for specific model
dbt test --select stg_sensor_raw
```

### Test Types
- **Not null**: Column values must not be null
- **Unique**: No duplicate values
- **Accepted values**: Column only contains specific values
- **Relationships**: Foreign key references are valid

## 🔍 Troubleshooting

### Issue: `Profile not found`
**Solution**: Ensure `profiles.yml` exists and paths are correct. dbt looks in `~/.dbt/` by default or specify `--profiles-dir ./`

### Issue: `Authentication failed`
**Solution**: Check Snowflake credentials in `profiles.yml`. Test connection:
```bash
dbt debug
```

### Issue: `source not found`
**Solution**: Ensure raw data table exists and database/schema names match in dbt YAML

## 📝 Development Workflow

1. Write SQL in `models/staging/` or `models/marts/`
2. Run `dbt run` to test
3. Run `dbt test` to validate data quality
4. Update `models/yml` files to document columns
5. Commit to Git
6. Run in production

## 🔗 Key References

- [dbt Documentation](https://docs.getdbt.com)
- [Snowflake + dbt Guide](https://docs.getdbt.com/guides/snowflake)
- Phase 2 setup: `../02_data_ingestion/snowflake_setup.sql`
- Project guide: `../plan-snowflake-project.prompt.md`

## Next Steps

→ **Phase 4: Analytics & Dashboards** - Create Quicksight dashboards from these marts tables
