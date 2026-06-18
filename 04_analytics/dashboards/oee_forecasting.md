# OEE & Forecasting Dashboard — Power BI Guide

## Overview
Equipment effectiveness monitoring and failure prediction for proactive maintenance planning.

**Data Sources**:
- `SMART_FACTORY.STAGING.FACT_OEE` — Daily OEE scores per equipment
- `SMART_FACTORY.STAGING.FACT_FORECASTING` — Failure prediction per equipment

---

## Step 1: Import Data into Power BI (Native Queries)

> ⚠️ Use Native Query to avoid the `null to Text` connector bug

### 1.1 Load FACT_OEE

In Power BI Desktop:
1. **Home → Get Data → Snowflake**
2. Enter server & warehouse (same as existing connection)
3. Click **Advanced Options → SQL Statement** and paste:

```sql
SELECT
    OEE_ID,
    EVENT_DATE,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    AVAILABILITY_PCT,
    PERFORMANCE_PCT,
    QUALITY_PCT,
    OEE_SCORE,
    OEE_CLASS,
    WEAKEST_COMPONENT,
    ACTUAL_READINGS,
    ANOMALY_COUNT,
    AVG_POWER_KW,
    AVG_HEALTH_SCORE,
    MIN_HEALTH_SCORE,
    AVG_TEMPERATURE_C,
    AVG_VIBRATION,
    DBT_UPDATED_AT
FROM SMART_FACTORY.STAGING.FACT_OEE
ORDER BY EVENT_DATE DESC, OEE_SCORE ASC
```

4. Rename table → `FACT_OEE`

---

### 1.2 Load FACT_FORECASTING

Repeat steps above with this query:

```sql
SELECT
    FORECAST_ID,
    FORECAST_AS_OF_DATE,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    CURRENT_HEALTH_SCORE,
    CURRENT_MIN_HEALTH,
    HEALTH_7D_AGO,
    HEALTH_CHANGE_7D,
    AVG_DAILY_DECLINE,
    DAYS_TO_FAILURE,
    PREDICTED_FAILURE_DATE,
    URGENCY_LEVEL,
    RECOMMENDED_ACTION,
    READING_COUNT,
    ANOMALY_COUNT,
    DBT_UPDATED_AT
FROM SMART_FACTORY.STAGING.FACT_FORECASTING
ORDER BY
    CASE URGENCY_LEVEL
        WHEN 'CRITICAL NOW' THEN 1
        WHEN 'CRITICAL'     THEN 2
        WHEN 'HIGH'         THEN 3
        WHEN 'MEDIUM'       THEN 4
        WHEN 'LOW'          THEN 5
        ELSE                     6
    END,
    DAYS_TO_FAILURE ASC NULLS LAST
```

4. Rename table → `FACT_FORECASTING`

---

## Step 2: Create DAX Measures

In Power BI → Home → **New Measure**, create the following:

### OEE Measures (from FACT_OEE)

```dax
Avg OEE Score =
AVERAGE('FACT_OEE'[OEE_SCORE])
```

```dax
Avg Availability =
AVERAGE('FACT_OEE'[AVAILABILITY_PCT])
```

```dax
Avg Performance =
AVERAGE('FACT_OEE'[PERFORMANCE_PCT])
```

```dax
Avg Quality =
AVERAGE('FACT_OEE'[QUALITY_PCT])
```

```dax
World Class Machines =
CALCULATE(
    DISTINCTCOUNT('FACT_OEE'[EQUIPMENT_ID]),
    'FACT_OEE'[OEE_CLASS] = "WORLD CLASS"
)
```

### Forecasting Measures (from FACT_FORECASTING)

```dax
Machines at Critical Risk =
CALCULATE(
    COUNTROWS('FACT_FORECASTING'),
    'FACT_FORECASTING'[URGENCY_LEVEL] IN {"CRITICAL NOW", "CRITICAL"}
)
```

```dax
Avg Days to Failure =
AVERAGEX(
    FILTER('FACT_FORECASTING', 'FACT_FORECASTING'[DAYS_TO_FAILURE] <> BLANK()),
    'FACT_FORECASTING'[DAYS_TO_FAILURE]
)
```

```dax
Min Days to Failure =
MINX(
    FILTER('FACT_FORECASTING', 'FACT_FORECASTING'[DAYS_TO_FAILURE] <> BLANK()),
    'FACT_FORECASTING'[DAYS_TO_FAILURE]
)
```

---

## Step 3: Build Dashboard Layout

### Row 1 — KPI Cards (4 cards across the top)

| Card | Measure | Format | Color Rule |
|------|---------|--------|------------|
| Overall OEE | `Avg OEE Score` | `##.#"%"` | 🟢 ≥85, 🟡 ≥65, 🔴 <65 |
| Availability | `Avg Availability` | `##.#"%"` | 🟢 ≥90, 🟡 ≥75, 🔴 <75 |
| Performance | `Avg Performance` | `##.#"%"` | 🟢 ≥90, 🟡 ≥75, 🔴 <75 |
| Quality | `Avg Quality` | `##.#"%"` | 🟢 ≥95, 🟡 ≥85, 🔴 <85 |

---

### Row 2 — OEE Charts (2 visuals side by side)

#### Visual A: OEE by Equipment (Clustered Bar Chart)
- **Y-axis**: `EQUIPMENT_ID`
- **X-axis**: `Avg OEE Score`
- **Color**: Conditional by `OEE_CLASS`
  - WORLD CLASS → Green `#2ECC71`
  - GOOD → Blue `#3498DB`
  - FAIR → Orange `#F39C12`
  - POOR → Red `#E74C3C`
- **Data label**: On (show % value)
- **Reference line**: Add constant line at X=85 → label "World Class"

#### Visual B: OEE Trend Over Time (Line Chart)
- **X-axis**: `EVENT_DATE`
- **Y-axis**: `Avg OEE Score`
- **Legend**: `EQUIPMENT_ID` (one line per machine)
- **Y-axis range**: Min=0, Max=100
- **Analytics**: Add constant line at 85 (World Class threshold)
- **Tooltip**: Show `AVAILABILITY_PCT`, `PERFORMANCE_PCT`, `QUALITY_PCT`

---

### Row 3 — Failure Forecasting Table

#### Visual: Forecasting Detail Table
Columns to show:

| Column | Display Name | Formatting |
|--------|-------------|------------|
| `EQUIPMENT_ID` | Machine | — |
| `EQUIPMENT_TYPE` | Type | — |
| `CURRENT_HEALTH_SCORE` | Health Score | `##.#"%"` |
| `AVG_DAILY_DECLINE` | Decline/Day | `#.##` (red if > 1) |
| `DAYS_TO_FAILURE` | Days Remaining | Bold, conditional color |
| `PREDICTED_FAILURE_DATE` | Predicted Failure | Date format |
| `URGENCY_LEVEL` | Urgency | Conditional color (see below) |
| `RECOMMENDED_ACTION` | Action Required | — |

**Conditional Row Color on `URGENCY_LEVEL`**:
- `CRITICAL NOW` → Background `#FF0000`, Text White
- `CRITICAL` → Background `#FF4444`, Text White
- `HIGH` → Background `#FF8C00`, Text White
- `MEDIUM` → Background `#FFD700`, Text Black
- `LOW` → Background `#90EE90`, Text Black
- `STABLE` → Background `#FFFFFF`, Text Black

---

### Row 4 — Slicers

Add 3 slicers (horizontal, top or side):

| Slicer | Table | Field | Style |
|--------|-------|-------|-------|
| Equipment Type | `FACT_OEE` | `EQUIPMENT_TYPE` | Tile |
| OEE Class | `FACT_OEE` | `OEE_CLASS` | Dropdown |
| Urgency Level | `FACT_FORECASTING` | `URGENCY_LEVEL` | Tile |

---

## Step 4: Final Layout Reference

```
┌──────────┬──────────┬──────────┬──────────┐
│ OEE      │ Avail.   │ Perform. │ Quality  │
│  72.4%   │  89.1%   │  81.3%   │  97.8%   │
└──────────┴──────────┴──────────┴──────────┘
┌──────────────────────┬───────────────────────┐
│ Bar: OEE by Machine  │ Line: OEE Trend 7 Days │
│ (sorted worst→best)  │ (one line / equipment) │
└──────────────────────┴───────────────────────┘
┌──────────────────────────────────────────────┐
│ Forecasting Table                            │
│ Machine | Health | Decline | Days | Urgency  │
│ Motor_1 |  42.3% |  -1.8/d |  7d  | 🟠 HIGH │
│ Motor_2 |  28.1% |  -2.1/d |  0d  | 🔴 CRIT │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ [Equipment Type ▼] [OEE Class ▼] [Urgency ▼] │
└──────────────────────────────────────────────┘
```

---

## Key Insights to Highlight

- **OEE Benchmark**: World-class manufacturing = ≥85% OEE
- **Weakest Component**: Check `WEAKEST_COMPONENT` column to know whether to fix Availability, Performance, or Quality
- **Forecasting accuracy**: Model uses 7-day linear regression on health score — best for gradual degradation patterns
- **Resume alignment**: This dashboard directly validates "forecasting equipment failures 5-7 days in advance" stated in CV
