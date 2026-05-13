-- Staging Model: stg_sensor_raw
-- Input:  SMART_FACTORY.RAW.RAW_SENSOR_DATA
-- Output: SMART_FACTORY.STAGING.STG_SENSOR_RAW (view)
-- Purpose: Clean, deduplicate, and validate raw sensor data

WITH source AS (
    SELECT * FROM {{ source('raw', 'RAW_SENSOR_DATA') }}
),

deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY TIMESTAMP, EQUIPMENT_ID
            ORDER BY LOAD_TIMESTAMP DESC
        ) AS row_num
    FROM source
),

cleaned AS (
    SELECT
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['TIMESTAMP', 'EQUIPMENT_ID']) }} AS sensor_id,

        -- Timestamps
        TIMESTAMP                           AS event_timestamp,
        DATE_TRUNC('hour', TIMESTAMP)       AS event_hour,
        CAST(TIMESTAMP AS DATE)             AS event_date,
        LOAD_TIMESTAMP                      AS loaded_at,

        -- Equipment info
        EQUIPMENT_ID,
        EQUIPMENT_TYPE,

        -- Sensor readings (cleaned)
        ROUND(TEMPERATURE, 2)           AS temperature_celsius,
        ROUND(VIBRATION, 4)             AS vibration_mm_s,
        ROUND(POWER_CONSUMPTION, 2)     AS power_kw,
        ROUND(HEALTH_SCORE, 2)          AS health_score,

        -- Anomaly flags
        IS_ANOMALY,
        ANOMALY_REASON,

        -- Data quality flags
        CASE
            WHEN TEMPERATURE < -50 OR TEMPERATURE > 500 THEN TRUE
            WHEN VIBRATION < 0 OR VIBRATION > 100      THEN TRUE
            WHEN POWER_CONSUMPTION < 0                  THEN TRUE
            WHEN HEALTH_SCORE < 0 OR HEALTH_SCORE > 100 THEN TRUE
            ELSE FALSE
        END AS is_out_of_range

    FROM deduplicated
    WHERE row_num = 1
      AND TIMESTAMP IS NOT NULL
      AND EQUIPMENT_ID IS NOT NULL
)

SELECT * FROM cleaned
