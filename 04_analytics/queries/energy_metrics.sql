-- Phase 4: Energy & Operations Queries
-- SQL queries aligned with SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION schema
-- ============================================================================

-- ============================================
-- QUERY 1: Total Energy Consumption by Equipment Type
-- ============================================
-- Business question: Which equipment type consumes the most power?
-- Grain: One row per equipment type

SELECT 
    EQUIPMENT_TYPE,
    COUNT(*) as hourly_readings,
    ROUND(SUM(total_power_kwh), 2) as total_kwh,
    ROUND(AVG(total_power_kwh), 2) as avg_kwh_per_hour,
    ROUND(MAX(total_power_kwh), 2) as peak_kwh,
    ROUND(MIN(total_power_kwh), 2) as min_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 3 DESC;


-- ============================================
-- QUERY 2: Hourly Power Consumption Trend
-- ============================================
-- Business question: When does power consumption peak?
-- Grain: One row per hour (across all equipment)

SELECT 
    event_hour,
    ROUND(SUM(total_power_kwh), 2) as hourly_total_kwh,
    COUNT(DISTINCT EQUIPMENT_ID) as equipment_count,
    ROUND(AVG(avg_temperature_c), 1) as avg_factory_temp
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 1;


-- ============================================
-- QUERY 3: Power Per Equipment (Individual Units)
-- ============================================
-- Business question: Which specific equipment unit is inefficient?
-- Grain: One row per equipment

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    COUNT(*) as hourly_readings,
    ROUND(SUM(total_power_kwh), 2) as total_kwh,
    ROUND(AVG(total_power_kwh), 2) as avg_kwh_per_hour,
    ROUND(AVG(avg_temperature_c), 2) as avg_operating_temp,
    ROUND(AVG(max_vibration), 2) as avg_vibration
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY 4 DESC;


-- ============================================
-- QUERY 4: Peak Hour Analysis
-- ============================================
-- Business question: What time of day has peak power consumption?
-- Grain: One row per hour of day (0-23)

SELECT 
    EXTRACT(HOUR FROM event_hour) as hour_of_day,
    ROUND(AVG(total_power_kwh), 2) as avg_kwh,
    COUNT(*) as samples,
    ROUND(MAX(total_power_kwh), 2) as peak_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================
-- QUERY 5: Temperature vs Power Efficiency
-- ============================================
-- Business question: Does higher temperature correlate with power efficiency?
-- Grain: One row per hour per equipment

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    event_hour,
    ROUND(avg_temperature_c, 2) as temp_celsius,
    ROUND(total_power_kwh, 2) as kwh,
    ROUND(total_power_kwh / NULLIF(avg_temperature_c + 1, 0), 2) as efficiency_ratio
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
    AND avg_temperature_c > 0
ORDER BY efficiency_ratio DESC
LIMIT 50;


-- ============================================
-- QUERY 6: Daily Energy Budget vs Actual
-- ============================================
-- Business question: Are we within our power budget?
-- Grain: One row per day

SELECT 
    event_date,
    ROUND(SUM(total_power_kwh), 2) as daily_kwh,
    150.0 as daily_budget_kwh,  -- Assumed budget
    ROUND(SUM(total_power_kwh) - 150.0, 2) as variance_kwh,
    CASE 
        WHEN SUM(total_power_kwh) > 150.0 THEN 'OVER'
        ELSE 'WITHIN'
    END as budget_status
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 1 DESC;


-- ============================================
-- QUERY 7: Anomaly Readings (High Power)
-- ============================================
-- Business question: When did equipment consume abnormally high power?
-- Grain: One row per anomalous reading

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    event_hour,
    total_power_kwh,
    avg_temperature_c,
    anomaly_count,
    ROUND(total_power_kwh / (SELECT AVG(total_power_kwh) FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION), 2) as deviation_ratio
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE event_hour >= DATEADD(day, -7, CURRENT_DATE)
    AND anomaly_count > 0
ORDER BY total_power_kwh DESC
LIMIT 20;
