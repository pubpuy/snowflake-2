# Data Dictionary: ALERT_PREDICTIVE_MAINTENANCE

## Table Purpose
Daily aggregated health metrics, anomaly rates, and predictive maintenance alerts for factory equipment. One row per equipment per day.

**Schema**: `SMART_FACTORY.MARTS`  
**Table Type**: Snowflake TABLE (materialized)  
**Row Count**: ~35 rows (5 equipment × 7 days)  
**Grain**: One row per equipment per day  
**Update Frequency**: Daily (after dbt run completes)

---

## Column Definitions

### Key Columns (Identifiers)

| Column | Data Type | Description | Example |
|--------|-----------|-------------|---------|
| `ALERT_ID` | VARCHAR(64) | Primary Key / Surrogate Key (event_date + EQUIPMENT_ID) | `d41d8cd98f00b204e9800998ecf8427e` |
| `EVENT_DATE` | DATE | Date when readings were aggregated | `2026-03-24` |
| `EQUIPMENT_ID` | VARCHAR(50) | Unique identifier for equipment unit | `Motor_001` |
| `EQUIPMENT_TYPE` | VARCHAR(50) | Category of equipment | `Motor`, `ConveyorBelt`, `Chiller` |

### Metric Columns (Aggregations)

| Column | Data Type | Description | Calculation | Normal Range |
|--------|-----------|-------------|-------------|--------------|
| `AVG_HEALTH_SCORE` | FLOAT | Average health score recorded during the day | `AVG(health_score)` | 70-100% |
| `MIN_HEALTH_SCORE` | FLOAT | Lowest health score recorded during the day | `MIN(health_score)` | 50-100% |
| `TOTAL_ANOMALIES` | INT | Count of anomalous readings in the day | `SUM(is_anomaly)` | 0-10 |
| `TOTAL_READINGS` | INT | Total sensor readings taken in the day | `COUNT(*)` | 1440 (1 per minute) |
| `ANOMALY_RATE_PCT` | FLOAT | Percentage of readings that were anomalies | `(total_anomalies * 100) / total_readings` | 0-5% |

### Sensor Maxima (Peak Readings)

| Column | Data Type | Description | Calculation | Normal Range |
|--------|-----------|-------------|-------------|--------------|
| `MAX_TEMPERATURE_C` | FLOAT | Maximum temperature recorded during the day | `MAX(temperature_celsius)` | 30-70°C |
| `MAX_VIBRATION` | FLOAT | Maximum vibration level recorded during the day | `MAX(vibration_mm_s)` | 0-10 mm/s |
| `MAX_POWER_KW` | FLOAT | Maximum power consumption recorded during the day | `MAX(power_kw)` | 5-25 kW |

### Risk & Recommendation Columns (Business Logic)

| Column | Data Type | Description | Calculation / Logic | Values |
|--------|-----------|-------------|---------------------|--------|
| `RISK_LEVEL` | VARCHAR(50) | Categorized maintenance urgency | Based on `min_health_score` and `anomaly_rate_pct` | `CRITICAL`, `WARNING`, `WATCH`, `NORMAL` |
| `RECOMMENDED_ACTION` | VARCHAR(200) | Specific task recommended for maintenance | Conditional string assignment | e.g. "IMMEDIATE INSPECTION REQUIRED" |
| `DBT_UPDATED_AT` | TIMESTAMP | Record metadata indicating when dbt ran | `CURRENT_TIMESTAMP()` | `2026-06-17 03:47:47` |

---

## Alert Severity Logic

The risk states are defined based on the lowest health score or the anomaly rate recorded during the day:

*   **CRITICAL**: `min_health_score < 30` or `anomaly_rate_pct > 20%`
    *   *Action*: `IMMEDIATE INSPECTION REQUIRED`
*   **WARNING**: `min_health_score < 60` or `anomaly_rate_pct > 10%`
    *   *Action*: `Schedule maintenance within 48 hours`
*   **WATCH**: `min_health_score < 80` or `anomaly_rate_pct > 5%`
    *   *Action*: `Monitor closely - schedule next maintenance window`
*   **NORMAL**: All other cases
    *   *Action*: `No action required`

---

## Sample Queries

### Q1: List All Immediate Maintenance Items
```sql
SELECT 
    EQUIPMENT_ID,
    RISK_LEVEL,
    MIN_HEALTH_SCORE,
    RECOMMENDED_ACTION
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE RISK_LEVEL IN ('CRITICAL', 'WARNING')
    AND EVENT_DATE = CURRENT_DATE();
```

### Q2: Aggregate Counts of Alerts by Urgency
```sql
SELECT 
    RISK_LEVEL,
    COUNT(*) as active_alerts
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
GROUP BY 1
ORDER BY 2 DESC;
```
