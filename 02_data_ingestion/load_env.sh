#!/bin/bash

# Load environment variables from phase2_config.env
set -a
source "$(dirname "$0")/phase2_config.env"
set +a

echo "✅ Environment variables loaded successfully"
echo "AWS_KEY_ID: $AWS_KEY_ID"
echo "AWS_SECRET_KEY: *****(hidden)"
echo "S3_BUCKET_NAME: $S3_BUCKET_NAME"
echo "S3_REGION: $S3_REGION"
