# Phase 4: Analytics & Dashboards

This folder contains configuration, queries, and documentation for business intelligence dashboards and analytics powered by Quicksight.

## 📁 Directory Structure

```
04_analytics/
├── dashboards/            # Dashboard definitions & configs
│   ├── energy_operations.md
│   └── maintenance_alerts.md
├── queries/               # SQL queries for dashboard visualizations
│   ├── energy_metrics.sql
│   └── maintenance_metrics.sql
├── data_dictionaries/     # Data model documentation
│   ├── fact_energy_consumption.md
│   └── alert_predictive_maintenance.md
└── README.md              # This file
```

## 📊 Dashboards

### Dashboard 1: Energy & Operations
**Purpose**: Monitor factory power consumption and operational efficiency

**Data Source**: `SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION`

**Key Visualizations**:
1. **Total Factory Power (Last 7 Days)** - Scorecard
2. **Power by Equipment** - Pie Chart
3. **Hourly Consumption Trend** - Line Chart
4. **Equipment Efficiency Comparison** - Bar Chart

**Business Questions Answered**:
- Which equipment consumes the most power?
- What time of day is peak consumption?
- How has efficiency changed over the week?

### Dashboard 2: Maintenance Alerts
**Purpose**: Predictive maintenance tracking and health monitoring

**Data Source**: `SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE`

**Key Visualizations**:
1. **Critical Alerts** - Table (actionable maintenance items)
2. **Equipment Health Trend** - Line Chart (degradation curves)
3. **Alert Severity Distribution** - Gauge (CRITICAL vs HIGH vs LOW)
4. **Time to Maintenance** - KPI cards

**Business Questions Answered**:
- Which equipment needs immediate maintenance?
- What's the health trajectory for each unit?
- How many critical issues do we have?

## 🔧 Setup Instructions

### Prerequisites
- Phase 3 (Data Transformation) completed successfully
- `SMART_FACTORY.MARTS` schema populated with tables
- AWS Quicksight subscription active

### Step 1: Connect Quicksight to Snowflake

1. Open AWS Quicksight (https://quicksight.aws.amazon.com)
2. Navigate to **Manage Data** → **New Dataset**
3. Select **Snowflake** as data source
4. Enter connection details:
   ```
   Server: your-account.us-east-1.snowflakecomputing.com
   Database: SMART_FACTORY
   Port: 443
   User: <your-quicksight-role>
   Password: <snowflake-password>
   ```
5. Click **Validate connection**

### Step 2: Create Datasets

Create two datasets in Quicksight:

**Dataset 1: Fact Energy Consumption**
```sql
SELECT *
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
```

**Dataset 2: Predictive Maintenance Alerts**
```sql
SELECT *
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
```

### Step 3: Build Dashboards

See detailed instructions in:
- [Energy & Operations Dashboard](dashboards/energy_operations.md)
- [Maintenance Alerts Dashboard](dashboards/maintenance_alerts.md)

## 📋 Query Library

Common analytics queries for ad-hoc analysis:

### Power Analysis
```sql
-- Total KWh by equipment (all time)
SELECT 
    EQUIPMENT_TYPE,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
GROUP BY 1
ORDER BY 2 DESC;

-- Peak hour analysis
SELECT 
    EXTRACT(HOUR FROM ENERGY_HOUR) as hour_of_day,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
GROUP BY 1
ORDER BY 2 DESC;
```

### Maintenance Analysis
```sql
-- Equipment health status
SELECT 
    EQUIPMENT_ID,
    MIN(MIN_HEALTH_PCT) as current_health,
    MAX(READING_TIMESTAMP) as last_reading
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
GROUP BY 1
ORDER BY 2 ASC;  -- Lowest health first
```

## 📚 Data Dictionaries

Detailed column documentation for dashboard builders:

- [Fact Energy Consumption](data_dictionaries/fact_energy_consumption.md)
- [Predictive Maintenance Alerts](data_dictionaries/alert_predictive_maintenance.md)

## 🎯 Use Cases

### Operations Manager
- "Show me power consumption trends by hour"
- "Which equipment is using the most energy this week?"
- "Compare energy efficiency across all motors"

### Maintenance Manager
- "Which equipment needs maintenance in the next 7 days?"
- "Show me health degradation curves for Motor_001"
- "How many critical alerts do we have?"

### Finance
- "What was our total energy cost last week?"
- "Which factory location is most efficient?"

### Executive
- "What's the current factory health status?"
- "Are we reducing unplanned downtime?"

## 🔍 Troubleshooting

### Issue: "Dataset connection failed"
**Solution**: 
- Verify Snowflake account ID and credentials
- Ensure Snowflake warehouse is running
- Check Snowflake network policies allow Quicksight IP

### Issue: "Mart tables not appearing in Quicksight"
**Solution**:
- Verify Phase 3 (dbt) run completed successfully
- Check that `SMART_FACTORY.MARTS` schema exists
- Refresh dataset metadata in Quicksight

### Issue: "Query timeout"
**Solution**:
- Increase Snowflake warehouse size
- Add WHERE clause to limit date range
- Create materialized aggregations for common queries

## 📈 Advanced Analytics

### Time-Series Forecasting
Use AWS Forecast to predict equipment health degradation:
```sql
-- Historical health trends (input for forecasting)
SELECT 
    READING_TIMESTAMP,
    EQUIPMENT_ID,
    MIN_HEALTH_PCT as health_score
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
ORDER BY EQUIPMENT_ID, READING_TIMESTAMP
```

### Anomaly Detection
Use Amazon Lookout for Equipment to detect unexpected sensor patterns

### Custom ML Models
Export data to SageMaker for predictive maintenance models

## 🔗 Key References

- [Quicksight User Guide](https://docs.aws.amazon.com/quicksight/)
- [Snowflake BI Connector](https://docs.snowflake.com/en/user-guide/bi-connector.html)
- Phase 3 (dbt): `../03_data_transformation/README.md`
- Project guide: `../plan-snowflake-project.prompt.md`

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review query library for similar examples
3. Consult project documentation
4. Check Quicksight/Snowflake logs
