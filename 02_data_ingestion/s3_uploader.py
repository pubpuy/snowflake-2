#!/usr/bin/env python3
"""
Phase 2: Upload sensor data to AWS S3 (Event-Driven / Continuous Ingestion)

This script drops the CSV files generated in Phase 1 into S3 one by one.
Since our Snowflake architecture relies on Snowpipe (AUTO_INGEST = TRUE),
as soon as each file arrives in the S3 bucket, it will trigger an Event (SQS) 
that tells Snowpipe to automatically load it into the RAW_SENSOR_DATA table.

Usage:
    python3 s3_uploader.py --bucket <your-bucket-name> --data-path ../01_data_simulation/data/batches --delay 5

The CSV files will be uploaded to:
    s3://<your-bucket-name>/sensor_raw/batch_001_*.csv
    s3://<your-bucket-name>/sensor_raw/batch_002_*.csv
    ...
"""

import boto3
import argparse
import logging
import time
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


def upload_batch_files(bucket_name, data_path, delay_seconds):
    """
    Upload batch CSV files to S3 one by one to simulate continuous flow.
    """
    s3_client = boto3.client('s3')
    data_dir = Path(data_path)
    
    if not data_dir.exists():
        logger.error(f"❌ Data path not found: {data_dir}")
        return False
    
    batch_files = sorted(data_dir.glob('batch_*.csv'))
    
    if not batch_files:
        logger.error(f"❌ No batch CSV files found in {data_dir}")
        return False
    
    logger.info(f"🚀 Found {len(batch_files)} batch files to upload.")
    logger.info("This script will upload files continuously. Snowpipe will handle the rest in the background.")
    
    for i, file_path in enumerate(batch_files, start=1):
        s3_key = f"sensor_raw/{file_path.name}"
        try:
            logger.info(f"[{i}/{len(batch_files)}] Uploading {file_path.name}...")
            s3_client.upload_file(str(file_path), bucket_name, s3_key)
            logger.info(f"  ✅ Uploaded to s3://{bucket_name}/{s3_key} (Triggering Snowpipe...)")
            
            # Simulate streaming by waiting between uploads
            if i < len(batch_files) and delay_seconds > 0:
                logger.info(f"  ⏳ Waiting {delay_seconds} seconds before next upload to simulate stream...")
                time.sleep(delay_seconds)
                
        except Exception as e:
            logger.error(f"  ❌ Failed to upload {file_path.name}: {e}")
            return False
    
    logger.info(f"\n✅ Upload complete! All {len(batch_files)} files pushed to S3.")
    logger.info("Note: Snowpipe usually takes 10-60 seconds to process files after they arrive in S3.")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Stream Phase 1 batch CSV files to S3 for Snowpipe Auto-Ingestion'
    )
    # Get bucket from env or require it
    import os
    from dotenv import load_dotenv
    load_dotenv('phase2_config.env') # Local env if available
    
    default_bucket = os.getenv('S3_BUCKET_NAME', 'factory-datalake-1776788959')
    
    parser.add_argument(
        '--bucket',
        default=default_bucket,
        help=f'S3 bucket name (default: {default_bucket})'
    )
    parser.add_argument(
        '--data-path',
        default='../01_data_simulation/data/batches',
        help='Path to folder containing batch CSV files'
    )
    parser.add_argument(
        '--delay',
        type=int,
        default=3,
        help='Delay in seconds between uploads to simulate streaming Data (default: 3)'
    )
    
    args = parser.parse_args()
    
    success = upload_batch_files(args.bucket, args.data_path, args.delay)
    exit(0 if success else 1)


if __name__ == '__main__':
    main()
