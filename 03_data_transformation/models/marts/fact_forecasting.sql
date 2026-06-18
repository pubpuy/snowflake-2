-- Mart Model: fact_forecasting
-- Input:  STG_SENSOR_RAW
-- Output: SMART_FACTORY.MARTS.FACT_FORECASTING (table)
-- Grain:  One row per equipment (latest forecast as of today)
-- Use:    Failure prediction dashboard, "Days to Failure" KPI
--
-- Method: Linear Regression on Health Score over 6-day window
-- NOTE:   Using LAG(6) instead of LAG(7) because simulation has exactly 7 days.
--         LAG(7) on day 7 would look for day 0 which doesn't exist → NULL.
-- ┌───────────────────────────────────────────────────────────────────────┐
-- │ daily_decline = (health_score_6d_ago - health_score_today) / 6       │
-- │ days_to_failure = (health_score_today - CRITICAL_THRESHOLD) / decline│
-- │ predicted_failure_date = CURRENT_DATE + days_to_failure              │
-- └───────────────────────────────────────────────────────────────────────┘
-- Critical threshold = 30 (defined in alert_predictive_maintenance.sql)

WITH staging AS (
    SELECT * FROM {{ ref('stg_sensor_raw') }}
    WHERE is_out_of_range = FALSE
),

-- Step 1: Daily average health score per equipment
daily_health AS (
    SELECT
        event_date,
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,
        ROUND(AVG(health_score), 2)     AS daily_avg_health,
        ROUND(MIN(health_score), 2)     AS daily_min_health,
        COUNT(*)                        AS reading_count,
        SUM(IS_ANOMALY)                 AS anomaly_count
    FROM staging
    GROUP BY 1, 2, 3
),

-- Step 2: Get health score from 7 days ago for each equipment
--         (to compute weekly decline rate)
health_with_lag AS (
    SELECT
        d.*,

        -- Health score 6 days prior (for slope calculation)
        -- Using LAG(6) because dataset has exactly 7 days;
        -- LAG(7) would return NULL on the latest row.
        LAG(daily_avg_health, 6) OVER (
            PARTITION BY EQUIPMENT_ID
            ORDER BY event_date
        ) AS health_7d_ago,

        -- Health score 1 day prior (for day-over-day change)
        LAG(daily_avg_health, 1) OVER (
            PARTITION BY EQUIPMENT_ID
            ORDER BY event_date
        ) AS health_yesterday,

        -- Row number to identify latest record
        ROW_NUMBER() OVER (
            PARTITION BY EQUIPMENT_ID
            ORDER BY event_date DESC
        ) AS row_num

    FROM daily_health d
),

-- Step 3: Calculate decline rate and forecast
--         Only use the latest available day per equipment
forecast_calc AS (
    SELECT
        event_date                                              AS forecast_as_of_date,
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,
        daily_avg_health                                        AS current_health_score,
        daily_min_health                                        AS current_min_health,
        health_7d_ago,
        health_yesterday,
        anomaly_count,
        reading_count,

        -- Daily decline rate: avg drop per day over 6-day window
        -- Positive value = declining, Negative = recovering
        ROUND(
            CASE
                WHEN health_7d_ago IS NULL THEN 0
                ELSE (health_7d_ago - daily_avg_health) / 6.0
            END,
        4)                                                      AS avg_daily_decline,

        -- Days until health drops below CRITICAL threshold (30)
        -- Formula: (current - 30) / decline_per_day
        ROUND(
            CASE
                -- Recovering or stable: no failure predicted
                WHEN health_7d_ago IS NULL
                    OR (health_7d_ago - daily_avg_health) <= 0  THEN NULL
                -- Already critical
                WHEN daily_avg_health <= 30                     THEN 0
                -- Normal linear projection
                ELSE (daily_avg_health - 30.0)
                        / NULLIF((health_7d_ago - daily_avg_health) / 6.0, 0)
            END,
        1)                                                      AS days_to_failure

    FROM health_with_lag
    WHERE row_num = 1   -- Latest record per equipment only
),

-- Step 4: Add predicted date and urgency classification
final AS (
    SELECT
        *,

        -- Predicted failure date
        CASE
            WHEN days_to_failure IS NOT NULL AND days_to_failure >= 0
                THEN DATEADD(day, CAST(days_to_failure AS INT), forecast_as_of_date)
            ELSE NULL
        END                                                     AS predicted_failure_date,

        -- Urgency level based on days remaining
        CASE
            WHEN current_health_score <= 30                     THEN 'CRITICAL NOW'
            WHEN days_to_failure IS NULL
                OR days_to_failure < 0                          THEN 'STABLE'
            WHEN days_to_failure <= 3                           THEN 'CRITICAL'
            WHEN days_to_failure <= 7                           THEN 'HIGH'
            WHEN days_to_failure <= 14                          THEN 'MEDIUM'
            ELSE                                                     'LOW'
        END                                                     AS urgency_level,

        -- Human-readable recommendation
        CASE
            WHEN current_health_score <= 30
                THEN 'STOP MACHINE — Immediate inspection required'
            WHEN days_to_failure IS NULL OR days_to_failure < 0
                THEN 'No failure predicted — Continue monitoring'
            WHEN days_to_failure <= 3
                THEN 'Schedule emergency maintenance TODAY'
            WHEN days_to_failure <= 7
                THEN 'Schedule maintenance within this week'
            WHEN days_to_failure <= 14
                THEN 'Plan maintenance in next 2 weeks'
            ELSE
                'No immediate action — Monitor monthly'
        END                                                     AS recommended_action

    FROM forecast_calc
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['forecast_as_of_date', 'EQUIPMENT_ID']) }} AS forecast_id,
    forecast_as_of_date,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,

    -- Current state
    current_health_score,
    current_min_health,

    -- Trend
    health_7d_ago,
    ROUND(current_health_score - health_7d_ago, 2)  AS health_change_7d,
    avg_daily_decline,

    -- Forecast
    days_to_failure,
    predicted_failure_date,
    urgency_level,
    recommended_action,

    -- Supporting data
    reading_count,
    anomaly_count,

    CURRENT_TIMESTAMP()                             AS dbt_updated_at

FROM final
ORDER BY
    CASE urgency_level
        WHEN 'CRITICAL NOW' THEN 1
        WHEN 'CRITICAL'     THEN 2
        WHEN 'HIGH'         THEN 3
        WHEN 'MEDIUM'       THEN 4
        WHEN 'LOW'          THEN 5
        ELSE                     6
    END,
    days_to_failure ASC NULLS LAST
