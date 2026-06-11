#!/usr/bin/env bash
# Daily off-site backup: pg_dump | gzip -> AWS S3.
# Required env: PG_URL (postgres connection url), BACKUP_BUCKET (s3 bucket
# name), plus AWS credentials for the write-only backup user
# (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY or a configured profile).
set -euo pipefail

: "${PG_URL:?PG_URL is required (postgres://user:pass@host:port/db)}"
: "${BACKUP_BUCKET:?BACKUP_BUCKET is required (s3 bucket name)}"

TS=$(date -u +%Y%m%dT%H%M%SZ)
DUMP="smc-${TS}.sql.gz"
TMP="/tmp/${DUMP}"

cleanup() { rm -f "${TMP}"; }
trap cleanup EXIT

echo "[backup] dumping to ${TMP}"
pg_dump "${PG_URL}" | gzip > "${TMP}"

echo "[backup] uploading to s3://${BACKUP_BUCKET}/${DUMP}"
aws s3 cp "${TMP}" "s3://${BACKUP_BUCKET}/${DUMP}"

echo "[backup] done: ${DUMP}"
