# Maintenance Alerts Dashboard

## Overview
Predictive maintenance tracking and equipment health monitoring for proactive maintenance planning.

**Data Source**: `SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE`

## Visualizations

### 1. Critical Alerts (Action Items)
**Type**: Table (Sortable, Filterable)

**SQL**:
```sql
SELECT 
    EQUIPMENT_ID,
    ALERT_SEVERITY,
    MIN_HEALTH_PCT as current_health,
    RECOMMENDED_ACTION,
    READING_TIMESTAMP as alert_time,
    DAYS_TO_FAILURE as estimated_days
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE ALERT_SEVERITY IN ('CRITICAL', 'HIGH')
ORDER BY READING_TIMESTAMP DESC
LIMIT 50
```

**Display**:
- Default sort: Most recent first
- Color-code rows: CRITICAL = Red, HIGH = Orange
- Actionable: Show equipment ID + specific action (replace, service, etc.)

### 2. Equipment Health Trend
**Type**: Line Chart (Multi-series)

**SQL**:
```sql
SELECT 
    READING_TIMESTAMP,
    EQUIPMENT_ID,
    MIN_HEALTH_PCT as health_score
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE READING_TIMESTAMP >= DATEADD(day, -7, CURRENT_DATE)
ORDER BY EQUIPMENT_ID, READING_TIMESTAMP
```

**Display**:
- One line per equipment
- Y-axis: Health % (0-100)
- X-axis: Time (7 days)
- Color-code zones: Green (>70%), Yellow (50-70%), Red (<50%)
- Insight: "Motor_001 health declining 2% per day, will reach critical in 3 days"

### 3. Alert Severity Distribution
**Type**: Gauge (or KPI cards for each severity)

**SQL**:
```sql
SELECT 
    ALERT_SEVERITY,
    COUNT(*) as alert_count
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE READING_TIMESTAMP >= DATEADD(day, -1, CURRENT_DATE)
GROUP BY 1
ORDER BY 1
```

**Display**:
- Gauge 1: CRITICAL count (Target: 0)
- Gauge 2: HIGH count (Target: <5)
- Gauge 3: MEDIUM count (Target: <10)
- Color: Green if below target, Red if above

### 4. Failure Prediction Timeline
**Type**: Horizontal Bar Chart

**SQL**:
```sql
SELECT 
    EQUIPMENT_ID,
    ALERT_SEVERITY,
    MIN_HEALTH_PCT as current_health,
    DAYS_TO_FAILURE as estimated_days_remaining
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE DAYS_TO_FAILURE IS NOT NULL
    AND DAYS_TO_FAILURE > 0
GROUP BY 1, 2, 3, 4
HAVING ROW_NUMBER() OVER (PARTITION BY EQUIPMENT_ID ORDER BY READING_TIMESTAMP DESC) = 1
ORDER BY 4 ASC
```

**Display**:
- Bar length: Days to failure (shorter = more urgent)
- Color-code: By severity
- Tooltip: Shows current health % and recommended action
- Insight: "Motor_001 needs attention in 3 days"

### 5. Anomaly Frequency Heatmap
**Type**: Heatmap (Equipment × Hour of Day)

**SQL**:
```sql
SELECT 
    EQUIPMENT_ID,
    EXTRACT(HOUR FROM READING_TIMESTAMP) as hour_of_day,
    COUNT(*) as anomaly_count
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE READING_TIMESTAMP >= DATEADD(day, -7, CURRENT_DATE)
    AND ANOMALY_COUNT > 0
GROUP BY 1, 2
```

**Display**:
- X-axis: Hour of day (0-23)
- Y-axis: Equipment ID
- Color intensity: Red = high anomalies, Green = low
- Insight: "Motor_001 shows anomalies between 2pm-4pm daily"

## Dashboard Filters (Interactive)

1. **Equipment Type**: Select Motor, ConveyorBelt, Chiller
2. **Equipment ID**: Drill-down to specific unit
3. **Alert Severity**: CRITICAL, HIGH, MEDIUM, LOW
4. **Health Range**: Slider (0-100%)
5. **Date Range**: Last 7 days (default), adjustable

## Quicksight Setup

1. Create new dashboard
2. Add dataset: `Predictive Maintenance Alerts`
3. Add visualizations in order above
4. Enable drill-down: Equipment Type → Equipment ID → Health Trend
5. Set refresh: Every 1 hour
6. Share with Maintenance team

## Business Workflows

### For Maintenance Manager (Daily)
1. Open dashboard at start of shift
2. Check "Critical Alerts" table
3. Identify equipment needing immediate maintenance
4. Plan maintenance activities based on "Days to Failure"
5. Document completed maintenance in external system

### For Operations Manager (Weekly)
1. Review "Equipment Health Trend"
2. Identify equipment showing accelerated degradation
3. Adjust production schedules if equipment at risk
4. Prepare budget requests for preventive maintenance

### For Executive (Monthly)
1. Review "Alert Severity Distribution"
2. Track trend: Is number of CRITICAL alerts increasing/decreasing?
3. Measure ROI: Compare maintenance costs vs downtime saved
4. Report to leadership on factory health status

## Key Metrics to Monitor

| Metric | Goal | Frequency |
|--------|------|-----------|
| CRITICAL alerts | 0 | Daily |
| HIGH alerts | < 5 | Daily |
| Average health | > 70% | Weekly |
| Equipment with health < 30% | 0 | Weekly |
| Mean time to failure | > 14 days | Monthly |
| Unplanned downtime | Trending down | Monthly |

## Alert Severity Definitions

- **CRITICAL** (Red): Health < 30%, failure likely within 3 days, immediate action required
- **HIGH** (Orange): Health 30-50%, degradation accelerating, plan maintenance this week
- **MEDIUM** (Yellow): Health 50-70%, normal degradation, schedule routine maintenance
- **LOW** (Green): Health > 70%, equipment operating normally, monitor only

## Recommended Actions (Examples)

| Alert Type | Severity | Recommended Action |
|------------|----------|-------------------|
| High vibration + declining health | CRITICAL | Replace bearing immediately |
| Temperature spike + power spike | HIGH | Schedule preventive servicing |
| Health declining 2%+ per day | HIGH | Increase inspection frequency |
| Minor anomalies | MEDIUM | Record in maintenance log |
| Normal operation | LOW | Continue monitoring |

## Integration with CMMS

Export alerts to your Computerized Maintenance Management System:

```sql
-- Export CRITICAL and HIGH alerts for CMMS integration
SELECT 
    EQUIPMENT_ID,
    ALERT_SEVERITY,
    RECOMMENDED_ACTION,
    READING_TIMESTAMP,
    CAST(NULL as VARCHAR) as CMMS_WORK_ORDER_ID  -- Will be filled by CMMS
FROM SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE
WHERE ALERT_SEVERITY IN ('CRITICAL', 'HIGH')
    AND READING_TIMESTAMP >= DATEADD(day, -1, CURRENT_DATE)
ORDER BY ALERT_SEVERITY DESC, READING_TIMESTAMP DESC
```

## Refresh Schedule
- **Critical hours** (6am-10pm): Every 15 minutes
- **Standard hours** (10pm-6am): Every 1 hour
- **Daily summary**: Overnight batch job

## Key Insights to Track

- **Health degradation rate**: Fastest declining equipment?
- **Failure prediction accuracy**: Are estimated failure dates accurate?
- **Alert response time**: How quickly is maintenance responding?
- **Unplanned vs planned downtime**: Ratio improving?
- **Equipment lifespan optimization**: Are we replacing too early/late?
