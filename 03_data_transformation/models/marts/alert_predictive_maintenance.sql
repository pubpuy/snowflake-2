-- Mart Model: alert_predictive_maintenance
-- Input:  STG_SENSOR_RAW
-- Output: SMART_FACTORY.MARTS.ALERT_PREDICTIVE_MAINTENANCE (table)
-- Use:    Predictive maintenance alerts, risk dashboards

WITH staging AS (
    SELECT * FROM {{ ref('stg_sensor_raw') }}
    WHERE is_out_of_range = FALSE
),

daily_equipment AS (
    SELECT
        event_date,
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,

        -- Health metrics
        ROUND(AVG(health_score), 2)         AS avg_health_score,
        ROUND(MIN(health_score), 2)         AS min_health_score,

        -- Anomaly metrics
        SUM(IS_ANOMALY)                     AS total_anomalies,
        COUNT(*)                            AS total_readings,
        ROUND(SUM(IS_ANOMALY) * 100.0 / NULLIF(COUNT(*), 0), 2) AS anomaly_rate_pct,

        -- Sensor maxima
        ROUND(MAX(temperature_celsius), 2)  AS max_temperature_c,
        ROUND(MAX(vibration_mm_s), 4)       AS max_vibration,
        ROUND(MAX(power_kw), 2)             AS max_power_kw

    FROM staging
    GROUP BY 1, 2, 3
),

with_alerts AS (
    SELECT
        *,
        -- Risk level classification
        CASE
            WHEN min_health_score < 30 OR anomaly_rate_pct > 20 THEN 'CRITICAL'
            WHEN min_health_score < 60 OR anomaly_rate_pct > 10 THEN 'WARNING'
            WHEN min_health_score < 80 OR anomaly_rate_pct > 5  THEN 'WATCH'
            ELSE 'NORMAL'
        END AS risk_level,

        -- Maintenance recommendation
        CASE
            WHEN min_health_score < 30 OR anomaly_rate_pct > 20
                THEN 'IMMEDIATE INSPECTION REQUIRED'
            WHEN min_health_score < 60 OR anomaly_rate_pct > 10
                THEN 'Schedule maintenance within 48 hours'
            WHEN min_health_score < 80 OR anomaly_rate_pct > 5
                THEN 'Monitor closely - schedule next maintenance window'
            ELSE 'No action required'
        END AS recommended_action

    FROM daily_equipment
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['event_date', 'EQUIPMENT_ID']) }} AS alert_id,
    *,
    CURRENT_TIMESTAMP() AS dbt_updated_at
FROM with_alerts
ORDER BY event_date DESC, risk_level, EQUIPMENT_ID
