#!/usr/bin/env python3
import os
import yaml
import snowflake.connector

def load_snowflake_config():
    # Path to profiles.yml
    profile_path = os.path.join(os.path.dirname(__file__), '../03_data_transformation/profiles.yml')
    with open(profile_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Extract dev target credentials
    dev_config = config['smart_factory']['outputs']['dev']
    return dev_config

def main():
    print("🔌 Loading Snowflake connection config from profiles.yml...")
    try:
        creds = load_snowflake_config()
    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        return

    print(f"🔑 Connecting to Snowflake Account: {creds['account']} as User: {creds['user']}...")
    try:
        conn = snowflake.connector.connect(
            user=creds['user'],
            password=creds['password'],
            account=creds['account'],
            warehouse=creds['warehouse'],
            database=creds['database'],
            schema=creds['schema'],
            role=creds['role']
        )
        cursor = conn.cursor()
        print("✅ Connection successful!")
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return

    try:
        # Step 1: Inspect Schemas
        print("\n=== 📁 Schemas in Database ===")
        cursor.execute("SHOW SCHEMAS")
        schemas = [row[1] for row in cursor.fetchall()]
        for s in schemas:
            print(f"- {s}")

        # Step 2: Inspect Tables/Views in STAGING and MARTS
        print("\n=== 📊 Tables and Views ===")
        for s in schemas:
            if s in ['INFORMATION_SCHEMA', 'PUBLIC']:
                continue
            cursor.execute(f"SHOW TABLES IN SCHEMA {s}")
            tables = [row[1] for row in cursor.fetchall()]
            cursor.execute(f"SHOW VIEWS IN SCHEMA {s}")
            views = [row[1] for row in cursor.fetchall()]
            
            print(f"Schema: {s}")
            if tables:
                print(f"  Tables: {', '.join(tables)}")
            if views:
                print(f"  Views: {', '.join(views)}")

        # Step 3: Run Row Count Checks
        print("\n=== 🔢 Row Count Summary ===")
        
        # Check raw table
        cursor.execute("SELECT COUNT(*) FROM SMART_FACTORY.RAW.RAW_SENSOR_DATA")
        print(f"RAW.RAW_SENSOR_DATA: {cursor.fetchone()[0]:,} rows")

        # Let's find out the exact name of the schemas where stg_sensor_raw, fact_energy_consumption, and alert_predictive_maintenance were created.
        # dbt v1.5 with target schema 'STAGING' typically places marts in 'STAGING_MARTS' or 'STAGING' depending on custom schema macros.
        # Let's check which schema contains fact_energy_consumption.
        marts_schema = None
        for s in schemas:
            cursor.execute(f"SHOW TABLES IN SCHEMA {s}")
            tables = [row[1].upper() for row in cursor.fetchall()]
            if 'FACT_ENERGY_CONSUMPTION' in tables:
                marts_schema = s
                break
        
        if not marts_schema:
            print("❌ Could not find FACT_ENERGY_CONSUMPTION table in any schema.")
            return
            
        print(f"Detected Marts Schema: {marts_schema}")
        
        cursor.execute(f"SELECT COUNT(*) FROM {creds['database']}.{marts_schema}.FACT_ENERGY_CONSUMPTION")
        print(f"{marts_schema}.FACT_ENERGY_CONSUMPTION: {cursor.fetchone()[0]} rows")
        
        cursor.execute(f"SELECT COUNT(*) FROM {creds['database']}.{marts_schema}.ALERT_PREDICTIVE_MAINTENANCE")
        print(f"{marts_schema}.ALERT_PREDICTIVE_MAINTENANCE: {cursor.fetchone()[0]} rows")

        # Step 4: Run Sample Energy Query
        print("\n=== ⚡ Sample Query: Energy Consumption by Equipment ===")
        query_energy = f"""
        SELECT 
            EQUIPMENT_TYPE,
            COUNT(*) as hourly_readings,
            ROUND(SUM(total_power_kwh), 2) as total_kwh,
            ROUND(AVG(avg_power_kw), 2) as avg_power_kw,
            ROUND(AVG(avg_temperature_c), 2) as avg_temp
        FROM {creds['database']}.{marts_schema}.FACT_ENERGY_CONSUMPTION
        GROUP BY 1
        ORDER BY total_kwh DESC
        """
        cursor.execute(query_energy)
        headers = [col[0] for col in cursor.description]
        print(f"{headers[0]:<20} | {headers[1]:<15} | {headers[2]:<12} | {headers[3]:<12} | {headers[4]:<10}")
        print("-" * 78)
        for row in cursor.fetchall():
            print(f"{row[0]:<20} | {row[1]:<15} | {row[2]:<12,} | {row[3]:<12} | {row[4]:<10}")

        # Step 5: Run Sample Maintenance Alerts Query
        print("\n=== 🚨 Sample Query: Maintenance Alerts by Risk Level ===")
        query_alerts = f"""
        SELECT 
            risk_level,
            COUNT(*) as record_count,
            ROUND(AVG(min_health_score), 2) as avg_min_health,
            SUM(total_anomalies) as total_anomalies
        FROM {creds['database']}.{marts_schema}.ALERT_PREDICTIVE_MAINTENANCE
        GROUP BY 1
        ORDER BY record_count DESC
        """
        cursor.execute(query_alerts)
        headers = [col[0] for col in cursor.description]
        print(f"{headers[0]:<15} | {headers[1]:<12} | {headers[2]:<15} | {headers[3]:<15}")
        print("-" * 65)
        for row in cursor.fetchall():
            print(f"{row[0]:<15} | {row[1]:<12} | {row[2]:<15} | {row[3]:<15}")

    except Exception as e:
        print(f"❌ Error executing queries: {e}")
    finally:
        cursor.close()
        conn.close()
        print("\n🔌 Connection closed.")

if __name__ == '__main__':
    main()
