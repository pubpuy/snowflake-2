-- Mart Model: fact_energy_consumption
-- Input:  STG_SENSOR_RAW
-- Output: SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION (table)
-- Grain:  One row per equipment per hour
-- Use:    Power trend analysis, equipment efficiency dashboards

WITH staging AS (
    SELECT * FROM {{ ref('stg_sensor_raw') }}
    WHERE is_out_of_range = FALSE
),

hourly_agg AS (
    SELECT
        event_hour,
        event_date,
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,

        -- Energy metrics
        ROUND(SUM(power_kw), 2)             AS total_power_kwh,
        ROUND(AVG(power_kw), 2)             AS avg_power_kw,
        ROUND(MAX(power_kw), 2)             AS peak_power_kw,

        -- Temperature metrics
        ROUND(AVG(temperature_celsius), 2)  AS avg_temperature_c,
        ROUND(MAX(temperature_celsius), 2)  AS max_temperature_c,

        -- Vibration metrics
        ROUND(AVG(vibration_mm_s), 4)       AS avg_vibration,
        ROUND(MAX(vibration_mm_s), 4)       AS max_vibration,

        -- Health
        ROUND(AVG(health_score), 2)         AS avg_health_score,
        ROUND(MIN(health_score), 2)         AS min_health_score,

        -- Anomaly count
        SUM(IS_ANOMALY)                     AS anomaly_count,
        COUNT(*)                            AS reading_count

    FROM staging
    GROUP BY 1, 2, 3, 4
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['event_hour', 'EQUIPMENT_ID']) }} AS fact_id,
    *,
    CURRENT_TIMESTAMP() AS dbt_updated_at
FROM hourly_agg
ORDER BY event_hour, EQUIPMENT_ID
