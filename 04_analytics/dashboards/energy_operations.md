# Energy & Operations Dashboard

## Overview
Real-time monitoring of factory power consumption and operational efficiency across all equipment.

**Data Source**: `SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION`

## Visualizations

### 1. Total Factory Power (Last 7 Days)
**Type**: Scorecard (KPI)

**SQL**:
```sql
SELECT 
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
```

**Display**:
- Large number: "1,250 kWh"
- Formatting: Comma-separated integers
- Conditional coloring: Green if below budget, Red if above

### 2. Power by Equipment Type
**Type**: Pie Chart

**SQL**:
```sql
SELECT 
    EQUIPMENT_TYPE,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC
```

**Display**:
- Slice labels: Equipment type + percentage
- Sort: Largest consumption first
- Insight: "Motor consumes 45% of total power"

### 3. Hourly Consumption Trend
**Type**: Line Chart

**SQL**:
```sql
SELECT 
    ENERGY_HOUR,
    ROUND(SUM(ENERGY_KWH), 2) as hourly_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 1
```

**Display**:
- X-axis: Time (hourly)
- Y-axis: Consumption (kWh)
- Legend: Show trend line + data points
- Insight: Peak hours typically 8am-12pm and 6pm-10pm

### 4. Equipment Efficiency Ranking
**Type**: Bar Chart (Sorted)

**SQL**:
```sql
SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    ROUND(AVG(AVG_TEMP_C), 2) as avg_temperature,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh,
    ROUND(SUM(ENERGY_KWH) / COUNT(*), 2) as kwh_per_reading
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY 4 DESC
```

**Display**:
- Horizontal bars sorted by energy consumption
- Color-code by equipment type
- Tooltip: Show all 3 metrics (temp, total KWh, efficiency)

### 5. Temperature vs Power Correlation
**Type**: Scatter Plot

**SQL**:
```sql
SELECT 
    AVG_TEMP_C,
    ENERGY_KWH,
    EQUIPMENT_TYPE
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
```

**Display**:
- X-axis: Temperature (°C)
- Y-axis: Power (kWh)
- Colors: By equipment type
- Insight: Some equipment shows linear temp-power correlation

## Dashboard Filters (Optional)

1. **Date Range**: Last 7 days (default), adjustable
2. **Equipment Type**: Select Motor, ConveyorBelt, Chiller
3. **Equipment ID**: Drill-down to specific unit

## Quicksight Setup

1. Create new dashboard
2. Add dataset: `Fact Energy Consumption`
3. Add visualizations in order above
4. Set up drill-down: Equipment Type → Equipment ID
5. Share dashboard with Operations team

## Refresh Schedule
- **Default**: Every 1 hour
- **Peak hours** (8am-6pm): Every 15 minutes
- **Off-hours**: Every 4 hours

## Key Insights to Track

- **Weekly consumption trend**: Is power usage increasing or decreasing?
- **Equipment efficiency**: Which units consume most per reading?
- **Peak hours**: When should we schedule maintenance to avoid power spikes?
- **Seasonal trends**: Patterns by time of day or day of week
