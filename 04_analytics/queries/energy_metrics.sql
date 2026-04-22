-- Phase 4: Energy & Operations Queries
-- SQL queries for dashboard and ad-hoc analysis

-- ============================================
-- QUERY 1: Total Energy Consumption by Equipment
-- ============================================
-- Business question: Which equipment consumes the most power?
-- Grain: One row per equipment type
-- Result: ~3 rows (Motor, ConveyorBelt, Chiller)

SELECT 
    EQUIPMENT_TYPE,
    COUNT(*) as hourly_readings,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh,
    ROUND(AVG(ENERGY_KWH), 2) as avg_kwh_per_hour,
    ROUND(MAX(ENERGY_KWH), 2) as peak_kwh,
    ROUND(MIN(ENERGY_KWH), 2) as min_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 3 DESC;


-- ============================================
-- QUERY 2: Hourly Power Consumption Trend
-- ============================================
-- Business question: When does power consumption peak?
-- Grain: One row per hour (across all equipment)
-- Result: ~168 rows (7 days × 24 hours)

SELECT 
    ENERGY_HOUR,
    ROUND(SUM(ENERGY_KWH), 2) as hourly_total_kwh,
    COUNT(DISTINCT EQUIPMENT_ID) as equipment_count,
    ROUND(AVG(AVG_TEMP_C), 1) as avg_factory_temp
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 1;


-- ============================================
-- QUERY 3: Power Per Equipment (Individual Units)
-- ============================================
-- Business question: Which specific equipment unit is inefficient?
-- Grain: One row per equipment
-- Result: ~5 rows (5 equipment units)

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    COUNT(*) as hourly_readings,
    ROUND(SUM(ENERGY_KWH), 2) as total_kwh,
    ROUND(AVG(ENERGY_KWH), 2) as avg_kwh_per_hour,
    ROUND(AVG(AVG_TEMP_C), 2) as avg_operating_temp,
    ROUND(AVG(MAX_VIBRATION), 2) as avg_vibration
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1, 2
ORDER BY 4 DESC;


-- ============================================
-- QUERY 4: Peak Hour Analysis
-- ============================================
-- Business question: What time of day has peak power consumption?
-- Grain: One row per hour of day (0-23)
-- Result: 24 rows

SELECT 
    EXTRACT(HOUR FROM ENERGY_HOUR) as hour_of_day,
    ROUND(AVG(ENERGY_KWH), 2) as avg_kwh,
    COUNT(*) as samples,
    ROUND(MAX(ENERGY_KWH), 2) as peak_kwh
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
GROUP BY 1
ORDER BY 2 DESC;


-- ============================================
-- QUERY 5: Temperature vs Power Efficiency
-- ============================================
-- Business question: Does higher temperature mean higher power consumption?
-- Grain: One row per hour per equipment
-- Result: ~840 rows

SELECT 
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    ENERGY_HOUR,
    ROUND(AVG_TEMP_C, 2) as temp_celsius,
    ROUND(ENERGY_KWH, 2) as kwh,
    ROUND(ENERGY_KWH / (AVG_TEMP_C + 1), 2) as efficiency_ratio
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
    AND AVG_TEMP_C > 0
ORDER BY EFFICIENCY_RATIO DESC
LIMIT 50;


-- ============================================
-- QUERY 6: Daily Energy Budget vs Actual
-- ============================================
-- Business question: Are we within our power budget?
-- Grain: One row per day

SELECT 
    CAST(ENERGY_HOUR AS DATE) as energy_date,
    ROUND(SUM(ENERGY_KWH), 2) as daily_kwh,
    150.0 as daily_budget_kwh,  -- Assumed budget
    ROUND(SUM(ENERGY_KWH) - 150.0, 2) as variance_kwh,
    CASE 
        WHEN SUM(ENERGY_KWH) > 150.0 THEN 'OVER'
        ELSE 'WITHIN'
    END as budget_status
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
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
    ENERGY_HOUR,
    ENERGY_KWH,
    AVG_TEMP_C,
    ANOMALY_COUNT,
    ROUND(ENERGY_KWH / (SELECT AVG(ENERGY_KWH) FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION), 2) as deviation_ratio
FROM SMART_FACTORY.MARTS.FACT_ENERGY_CONSUMPTION
WHERE ENERGY_HOUR >= DATEADD(day, -7, CURRENT_DATE)
    AND ANOMALY_COUNT > 0
ORDER BY ENERGY_KWH DESC
LIMIT 20;
