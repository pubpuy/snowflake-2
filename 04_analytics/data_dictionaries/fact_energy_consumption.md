# Data Dictionary: FACT_ENERGY_CONSUMPTION

## Table Purpose
Hourly aggregated energy consumption and operational metrics for factory equipment. One row per equipment per hour.

**Schema**: `SMART_FACTORY.MARTS`  
**Table Type**: Snowflake TABLE (materialized)  
**Row Count**: ~840 rows (5 equipment × 7 days × 24 hours)  
**Grain**: One row per equipment per hour  
**Update Frequency**: Daily (after dbt run completes)

---

## Column Definitions

### Dimension Columns (WHO, WHAT, WHEN)

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| `ENERGY_HOUR` | TIMESTAMP | Hour boundary when readings were aggregated | 2026-03-24 09:00:00 |
| `EQUIPMENT_ID` | VARCHAR(50) | Unique identifier for equipment unit | Motor_001 |
| `EQUIPMENT_TYPE` | VARCHAR(50) | Category of equipment | Motor, ConveyorBelt, Chiller |

### Metric Columns (HOW MUCH, AVERAGE)

| Column | Data Type | Description | Calculation | Normal Range |
|--------|-----------|-------------|-------------|--------------|
| `AVG_TEMP_C` | FLOAT | Average temperature during hour | AVG(TEMPERATURE_CELSIUS) | 30-70°C |
| `MAX_VIBRATION` | FLOAT | Maximum vibration reading during hour | MAX(VIBRATION_LEVEL) | 0-10 |
| `ENERGY_KWH` | FLOAT | Energy consumed during the hour | SUM(POWER_KW) / 60 | 5-25 kWh |
| `MIN_HEALTH_PCT` | FLOAT | Lowest health score recorded during hour | MIN(HEALTH_SCORE) | 0-100% |

### Count Columns

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| `READING_COUNT` | INT | Number of raw readings in this hour | 60 (1 per minute) |
| `ANOMALY_COUNT` | INT | Number of anomalous readings | 5 |

---

## Business Context

### What This Table Answers
- **"How much power did the factory use?"** → SUM(ENERGY_KWH)
- **"Which equipment uses the most energy?"** → GROUP BY EQUIPMENT_TYPE, SUM(ENERGY_KWH)
- **"What were peak consumption hours?"** → ORDER BY ENERGY_KWH DESC
- **"Is equipment overheating?"** → WHERE AVG_TEMP_C > 60
- **"When do anomalies occur?"** → WHERE ANOMALY_COUNT > 0

### Relationship to Other Tables

```
RAW_SENSOR_DATA (raw)
         ↓
    STG_SENSOR_RAW (staging)
         ↓
FACT_ENERGY_CONSUMPTION (marts) ← You are here
         ↓
Quicksight Dashboard
```

---

## Sample Queries

### Q1: Total Energy Last 7 Days
```sql
SELECT ROUND(SUM(ENERGY_KWH), 2) as total_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE);
```
**Expected**: ~1,200 kWh

### Q2: Equipment Efficiency Ranking
```sql
SELECT 
    EQUIPMENT_ID,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh,
    ROUND(AVG(AVG_TEMP_C), 2) as avg_temp
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC;
```
**Expected**: Motor units highest consumption, Chiller lowest

### Q3: Peak Hour of Day
```sql
SELECT 
    EXTRACT(HOUR FROM ENERGY_HOUR) as hour,
    ROUND(AVG(ENERGY_KWH), 2) as avg_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;
```
**Expected**: Hour 12 (noon) or Hour 6 (evening)

---

## Data Quality Rules

| Rule | Description | Action if Violated |
|------|-------------|-------------------|
| NOT NULL | All columns must have values | Reject row in test |
| ENERGY_KWH > 0 | Energy consumption must be positive | Flag in test |
| AVG_TEMP_C between -50 and 100 | Temperature in valid range | Set to NULL |
| MIN_HEALTH_PCT between 0 and 100 | Health score is percentage | Flag in test |
| READING_COUNT = 60 | Expect one reading per minute (60 per hour) | Log warning if different |

---

## Common Issues & Solutions

### Issue: No data for expected hour
**Cause**: Raw sensor data missing or dbt job failed  
**Solution**: Check `dbt run` logs, verify `RAW_SENSOR_DATA` has data

### Issue: Energy consumption unusually high/low
**Cause**: Equipment running in degraded mode or extra load  
**Solution**: Cross-check with `MIN_HEALTH_PCT` and `ANOMALY_COUNT`

### Issue: Temperature shows NULL
**Cause**: Sensor malfunction or out-of-range reading  
**Solution**: Check raw data quality, may indicate equipment issue

---

## Refresh Logic

This table is rebuilt daily via dbt:

```bash
dbt run --select fact_energy_consumption
```

**Schedule**:
- Development: Manual run as needed
- Production: 2:00 AM UTC daily

**Timing**: ~30 seconds (840 rows)

---

## Next Steps

- **For dashboards**: Use in Quicksight visualizations (see Energy Operations Dashboard)
- **For analysis**: Join with `ALERT_PREDICTIVE_MAINTENANCE` for maintenance-energy correlation
- **For reporting**: Aggregate by week/month for executive summaries
