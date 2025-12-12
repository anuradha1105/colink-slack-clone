#!/bin/sh
# MinIO initialization script - creates buckets and sets public access

# Wait for MinIO to be ready
echo "Waiting for MinIO to be ready..."
until mc alias set local http://minio:9000 minioadmin minioadmin 2>/dev/null; do
  echo "MinIO not ready yet, waiting..."
  sleep 2
done

echo "MinIO is ready. Creating buckets..."

# Create buckets if they don't exist
mc mb local/colink --ignore-existing
mc mb local/colink-thumbnails --ignore-existing

# Set public download access
echo "Setting public access policies..."
mc anonymous set download local/colink
mc anonymous set download local/colink-thumbnails

echo "MinIO initialization complete!"
