-- Mart Model: fact_oee
-- Input:  STG_SENSOR_RAW
-- Output: SMART_FACTORY.MARTS.FACT_OEE (table)
-- Grain:  One row per equipment per day
-- Use:    OEE dashboard, equipment effectiveness analysis
--
-- OEE Formula: Availability × Performance × Quality
-- ┌─────────────────────────────────────────────────────────────────┐
-- │ Availability = Actual Readings / Expected Readings (1,440/day) │
-- │ Performance  = Avg Power / Max Possible Power (per type)        │
-- │ Quality      = 1 - (Anomaly Count / Total Readings)             │
-- │ OEE          = Availability × Performance × Quality × 100       │
-- └─────────────────────────────────────────────────────────────────┘

WITH staging AS (
    SELECT * FROM {{ ref('stg_sensor_raw') }}
    WHERE is_out_of_range = FALSE
),

-- Step 1: Aggregate daily metrics per equipment
daily_metrics AS (
    SELECT
        event_date,
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,

        -- Readings count
        COUNT(*)                                    AS actual_readings,
        SUM(IS_ANOMALY)                             AS anomaly_count,

        -- Power metrics
        ROUND(AVG(power_kw), 4)                     AS avg_power_kw,
        ROUND(MAX(power_kw), 4)                     AS max_power_kw,

        -- Health metrics
        ROUND(AVG(health_score), 2)                 AS avg_health_score,
        ROUND(MIN(health_score), 2)                 AS min_health_score,

        -- Sensor averages
        ROUND(AVG(temperature_celsius), 2)          AS avg_temperature_c,
        ROUND(AVG(vibration_mm_s), 4)               AS avg_vibration

    FROM staging
    GROUP BY 1, 2, 3
),

-- Step 2: Calculate max possible power per equipment type (benchmark)
-- Used to normalize Performance score across different equipment types
type_benchmarks AS (
    SELECT
        EQUIPMENT_TYPE,
        MAX(avg_power_kw)   AS benchmark_power_kw
    FROM daily_metrics
    GROUP BY 1
),

-- Step 3: Calculate OEE Components
oee_components AS (
    SELECT
        d.*,
        b.benchmark_power_kw,

        -- AVAILABILITY: % of expected 1-minute readings captured in a day
        -- Expected = 1,440 readings (60 min × 24 hr × 1 reading/min)
        ROUND(LEAST(d.actual_readings / 1440.0, 1.0), 4)           AS availability,

        -- PERFORMANCE: Avg power vs. best power seen (same equipment type)
        -- Represents how hard the machine is working relative to its peak
        ROUND(
            CASE
                WHEN b.benchmark_power_kw = 0 THEN 0
                ELSE LEAST(d.avg_power_kw / b.benchmark_power_kw, 1.0)
            END,
        4)                                                          AS performance,

        -- QUALITY: % of readings that were NOT anomalous
        ROUND(
            1.0 - (d.anomaly_count / NULLIF(d.actual_readings, 0)),
        4)                                                          AS quality

    FROM daily_metrics d
    LEFT JOIN type_benchmarks b
        ON d.EQUIPMENT_TYPE = b.EQUIPMENT_TYPE
),

-- Step 4: Compute final OEE and classify
final AS (
    SELECT
        *,

        -- OEE Score (0–100%)
        ROUND(availability * performance * quality * 100, 2)        AS oee_score,

        -- OEE Classification (World-class benchmark: >85%)
        CASE
            WHEN availability * performance * quality * 100 >= 85   THEN 'WORLD CLASS'
            WHEN availability * performance * quality * 100 >= 65   THEN 'GOOD'
            WHEN availability * performance * quality * 100 >= 50   THEN 'FAIR'
            ELSE                                                          'POOR'
        END                                                          AS oee_class,

        -- Identify the weakest OEE component (for drill-down insight)
        CASE
            WHEN LEAST(availability, performance, quality)
                    = availability                                  THEN 'Availability'
            WHEN LEAST(availability, performance, quality)
                    = performance                                   THEN 'Performance'
            ELSE                                                         'Quality'
        END                                                          AS weakest_component

    FROM oee_components
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['event_date', 'EQUIPMENT_ID']) }} AS oee_id,
    event_date,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,

    -- OEE Components (as %)
    ROUND(availability * 100, 2)    AS availability_pct,
    ROUND(performance * 100, 2)     AS performance_pct,
    ROUND(quality * 100, 2)         AS quality_pct,

    -- Final OEE
    oee_score,
    oee_class,
    weakest_component,

    -- Supporting metrics
    actual_readings,
    anomaly_count,
    avg_power_kw,
    benchmark_power_kw,
    avg_health_score,
    min_health_score,
    avg_temperature_c,
    avg_vibration,

    CURRENT_TIMESTAMP()             AS dbt_updated_at

FROM final
ORDER BY event_date DESC, oee_score ASC
