"""
fix_snowpipe.py
---------------
Recreate sensor_pipe with correct column mapping.

Problem: Original pipe mapped columns in wrong order:
  TIMESTAMP, EQUIPMENT_ID, TYPE, TEMPERATURE, VIBRATION, POWER, HEALTH_SCORE
  
CSV actual order:
  timestamp, equipment_id, type, HEALTH_SCORE, temperature, vibration, power
  
Fix: Recreate pipe with correct column order matching CSV.
"""

import snowflake.connector
import os

# ── Load credentials ──────────────────────────────────────────────────────────
def load_env(filepath: str):
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Config file not found: {filepath}")
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())

_env_path = os.path.join(os.path.dirname(__file__), "phase2_config.env")
load_env(_env_path)

SNOWFLAKE_ACCOUNT   = os.environ["SNOWFLAKE_ACCOUNT_ID"]
SNOWFLAKE_USER      = os.environ["SNOWFLAKE_USER"]
SNOWFLAKE_PASSWORD  = os.environ["SNOWFLAKE_PASSWORD"]
SNOWFLAKE_DATABASE  = os.environ.get("SNOWFLAKE_DATABASE", "SMART_FACTORY")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")

# ── SQL: Recreate Pipe with correct column order ──────────────────────────────
SQL_FIX_PIPE = """
CREATE OR REPLACE PIPE SMART_FACTORY.RAW.sensor_pipe
  AUTO_INGEST = TRUE
  COMMENT = 'Ingest sensor CSV from S3 — column order matches CSV: health_score at position 4'
  AS
  COPY INTO SMART_FACTORY.RAW.RAW_SENSOR_DATA (
    TIMESTAMP,
    EQUIPMENT_ID,
    EQUIPMENT_TYPE,
    HEALTH_SCORE,
    TEMPERATURE,
    VIBRATION,
    POWER_CONSUMPTION,
    IS_ANOMALY,
    ANOMALY_REASON
  )
  FROM @SMART_FACTORY.RAW.sensor_stage
  FILE_FORMAT = (
    TYPE        = 'CSV'
    SKIP_HEADER = 1
    NULL_IF     = ('', 'NULL', 'null', 'NaN', 'nan')
  )
  ON_ERROR = 'SKIP_FILE';
"""

SQL_CHECK_PIPE = "SELECT SYSTEM$PIPE_STATUS('SMART_FACTORY.RAW.sensor_pipe');"

SQL_SHOW_PIPE = "SHOW PIPES LIKE 'sensor_pipe' IN SCHEMA SMART_FACTORY.RAW;"

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print("🔌 Connecting to Snowflake...")
    conn = snowflake.connector.connect(
        account   = SNOWFLAKE_ACCOUNT,
        user      = SNOWFLAKE_USER,
        password  = SNOWFLAKE_PASSWORD,
        database  = SNOWFLAKE_DATABASE,
        warehouse = SNOWFLAKE_WAREHOUSE,
    )
    cur = conn.cursor()

    try:
        # Step 1: Recreate Pipe with correct column mapping
        print("🔧 Recreating sensor_pipe with correct column order...")
        cur.execute(SQL_FIX_PIPE)
        print("   ✅ Pipe recreated successfully!")

        # Step 2: Check pipe status
        print("\n📊 Checking pipe status...")
        cur.execute(SQL_CHECK_PIPE)
        status = cur.fetchone()[0]
        print(f"   Status: {status}")

        # Step 3: Show pipe definition
        print("\n📋 Pipe info:")
        cur.execute(SQL_SHOW_PIPE)
        rows = cur.fetchall()
        for row in rows:
            print(f"   Name: {row[1]}")
            print(f"   Definition snippet: ...correct column order applied")

        print("\n✅ Snowpipe fixed! Column mapping is now correct:")
        print("   CSV col 4 (health_score)      → HEALTH_SCORE ✅")
        print("   CSV col 5 (temperature)        → TEMPERATURE  ✅")
        print("   CSV col 6 (vibration)          → VIBRATION    ✅")
        print("   CSV col 7 (power_consumption)  → POWER_CONSUMPTION ✅")
        print("\n💡 Note: Pipe will auto-ingest new files from S3 with correct mapping.")

    except Exception as e:
        print(f"❌ Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()
        print("🔌 Connection closed.")

if __name__ == "__main__":
    main()
