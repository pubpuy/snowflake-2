#!/usr/bin/env python3
"""
Phase 2: Upload sensor data to AWS S3

This script uploads the CSV files generated in Phase 1 to S3,
where Snowpipe will automatically ingest them into Snowflake.

Usage:
    python3 s3_uploader.py --bucket factory-datalake-1776788959 --data-path ../01_data_simulation/data/batches

The CSV files will be uploaded to:
    s3://factory-datalake-1776788959/sensor_raw/batch_001_*.csv
    s3://factory-datalake-1776788959/sensor_raw/batch_002_*.csv
    ...
"""

import boto3
import os
import argparse
import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


def upload_batch_files(bucket_name, data_path):
    """
    Upload all batch CSV files to S3.
    
    Args:
        bucket_name: S3 bucket name (e.g., 'factory-datalake-1776788959')
        data_path: Path to folder containing batch CSV files
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
    
    logger.info(f"Found {len(batch_files)} batch files to upload")
    
    for file_path in batch_files:
        s3_key = f"sensor_raw/{file_path.name}"
        try:
            logger.info(f"Uploading {file_path.name}...")
            s3_client.upload_file(
                str(file_path),
                bucket_name,
                s3_key
            )
            logger.info(f"  ✅ Uploaded to s3://{bucket_name}/{s3_key}")
        except Exception as e:
            logger.error(f"  ❌ Failed to upload {file_path.name}: {e}")
            return False
    
    # List uploaded files
    logger.info("\n📋 Files in S3:")
    response = s3_client.list_objects_v2(
        Bucket=bucket_name,
        Prefix='sensor_raw/'
    )
    
    if 'Contents' in response:
        for obj in response['Contents']:
            if obj['Key'] != 'sensor_raw/':  # Skip the folder itself
                size_mb = obj['Size'] / (1024 * 1024)
                logger.info(f"  s3://{bucket_name}/{obj['Key']} ({size_mb:.2f} MB)")
    
    logger.info(f"\n✅ Upload complete! {len(batch_files)} files ready for Snowpipe ingestion")
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Upload Phase 1 batch CSV files to S3'
    )
    parser.add_argument(
        '--bucket',
        required=True,
        help='S3 bucket name (e.g., factory-datalake-1776788959)'
    )
    parser.add_argument(
        '--data-path',
        default='../01_data_simulation/data/batches',
        help='Path to folder containing batch CSV files'
    )
    
    args = parser.parse_args()
    
    success = upload_batch_files(args.bucket, args.data_path)
    exit(0 if success else 1)


if __name__ == '__main__':
    main()
