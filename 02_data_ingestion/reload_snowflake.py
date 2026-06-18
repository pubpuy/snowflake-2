"""
reload_snowflake.py
-------------------
Truncate RAW_SENSOR_DATA and reload fresh data from S3 Stage into Snowflake.
Run this after re-uploading new batch CSV files to S3.

Setup:
  Update SNOWFLAKE_PASSWORD in 02_data_ingestion/phase2_config.env
  (phase2_config.env is in .gitignore — safe to store credentials there)
"""

import snowflake.connector
import os

# ── Load credentials from phase2_config.env ───────────────────────────────────
def load_env(filepath: str):
    """Load key=value pairs from a .env file into os.environ."""
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"Config file not found: {filepath}")
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())

# Load from phase2_config.env (relative to this script)
_env_path = os.path.join(os.path.dirname(__file__), "phase2_config.env")
load_env(_env_path)

# ── Credentials (read from env) ────────────────────────────────────────────────
SNOWFLAKE_ACCOUNT   = os.environ["SNOWFLAKE_ACCOUNT_ID"]
SNOWFLAKE_USER      = os.environ["SNOWFLAKE_USER"]
SNOWFLAKE_PASSWORD  = os.environ["SNOWFLAKE_PASSWORD"]   # ← แก้ใน phase2_config.env
SNOWFLAKE_DATABASE  = os.environ.get("SNOWFLAKE_DATABASE", "SMART_FACTORY")
SNOWFLAKE_SCHEMA    = os.environ.get("SNOWFLAKE_SCHEMA", "RAW")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
SNOWFLAKE_STAGE     = "sensor_stage"
SNOWFLAKE_TABLE     = "RAW_SENSOR_DATA"

# ── SQL Commands ──────────────────────────────────────────────────────────────
SQL_TRUNCATE = f"TRUNCATE TABLE {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE};"

SQL_COPY_INTO = f"""
COPY INTO {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE} (
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
FROM @{SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_STAGE}
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'NaN', 'nan')
    EMPTY_FIELD_AS_NULL = TRUE
)
PATTERN = '.*batch.*\\.csv'
ON_ERROR = 'CONTINUE'
FORCE = TRUE
PURGE = FALSE;
"""

SQL_COUNT = f"SELECT COUNT(*) AS total_rows FROM {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE};"

SQL_HEALTH_CHECK = f"""
SELECT
    equipment_id,
    ROUND(AVG(health_score), 2) AS avg_health,
    ROUND(MIN(health_score), 2) AS min_health,
    COUNT(*) AS readings
FROM {SNOWFLAKE_DATABASE}.{SNOWFLAKE_SCHEMA}.{SNOWFLAKE_TABLE}
GROUP BY 1
ORDER BY 1;
"""

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    print("🔌 Connecting to Snowflake...")
    conn = snowflake.connector.connect(
        account   = SNOWFLAKE_ACCOUNT,
        user      = SNOWFLAKE_USER,
        password  = SNOWFLAKE_PASSWORD,
        database  = SNOWFLAKE_DATABASE,
        schema    = SNOWFLAKE_SCHEMA,
        warehouse = SNOWFLAKE_WAREHOUSE,
    )
    cur = conn.cursor()

    try:
        # Step 1: Truncate old data
        print(f"🗑️  Truncating {SNOWFLAKE_TABLE}...")
        cur.execute(SQL_TRUNCATE)
        print("   ✅ Table truncated.")

        # Step 2: COPY INTO from Stage
        print(f"📥 Loading fresh data from Stage '@{SNOWFLAKE_STAGE}'...")
        cur.execute(SQL_COPY_INTO)
        results = cur.fetchall()
        loaded = sum(r[3] for r in results if r[3])  # rows_loaded column
        errors = sum(r[4] for r in results if r[4])  # errors_seen column
        print(f"   ✅ Files processed: {len(results)}")
        print(f"   ✅ Rows loaded:     {loaded:,}")
        print(f"   ⚠️  Errors seen:    {errors}")

        # Step 3: Row count verification
        print("\n📊 Verifying row count...")
        cur.execute(SQL_COUNT)
        total = cur.fetchone()[0]
        print(f"   Total rows in {SNOWFLAKE_TABLE}: {total:,}")

        # Step 4: Health score sanity check
        print("\n🏥 Health score check per equipment (should be 85-100%):")
        cur.execute(SQL_HEALTH_CHECK)
        rows = cur.fetchall()
        print(f"   {'Equipment':<25} {'Avg Health':>12} {'Min Health':>12} {'Readings':>10}")
        print(f"   {'-'*62}")
        for row in rows:
            status = "✅" if row[1] > 30 else "⚠️ "
            print(f"   {status} {row[0]:<23} {row[1]:>12.2f} {row[2]:>12.2f} {row[3]:>10,}")

        print("\n🎉 Reload complete! Now re-run dbt to refresh all models.")

    except Exception as e:
        print(f"❌ Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()
        print("🔌 Connection closed.")

if __name__ == "__main__":
    main()
