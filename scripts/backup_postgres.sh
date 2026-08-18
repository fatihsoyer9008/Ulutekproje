#!/usr/bin/env bash
# Task 7.6: daily PostgreSQL backup for the Hetzner production stack.
#
# Runs a `pg_dump` inside the running postgres container (no host-side
# Postgres client required), gzips the result, writes it to a directory
# that only root can read, and prunes dumps older than the retention
# window. Intended to run from cron as root.
#
# Usage: backup_postgres.sh
# Env overrides: POSTGRES_CONTAINER, POSTGRES_USER, POSTGRES_DB,
#                BACKUP_DIR, RETENTION_DAYS

set -euo pipefail

POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-ulutekproje_postgres_1}"
POSTGRES_USER="${POSTGRES_USER:-receipt_app}"
POSTGRES_DB="${POSTGRES_DB:-receipt_app}"
BACKUP_DIR="${BACKUP_DIR:-/root/fiskon-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
dump_file="${BACKUP_DIR}/${POSTGRES_DB}_${timestamp}.sql.gz"
tmp_file="${dump_file}.partial"

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

echo "[backup_postgres] starting dump of ${POSTGRES_DB} at ${timestamp}"

docker exec "${POSTGRES_CONTAINER}" \
  pg_dump --username "${POSTGRES_USER}" --no-password --format=plain "${POSTGRES_DB}" \
  | gzip > "${tmp_file}"

mv "${tmp_file}" "${dump_file}"
chmod 600 "${dump_file}"

echo "[backup_postgres] wrote ${dump_file} ($(du -h "${dump_file}" | cut -f1))"

deleted_count=0
while IFS= read -r -d '' old_file; do
  rm -f "${old_file}"
  deleted_count=$((deleted_count + 1))
done < <(find "${BACKUP_DIR}" -maxdepth 1 -name "${POSTGRES_DB}_*.sql.gz" -mtime "+${RETENTION_DAYS}" -print0)

echo "[backup_postgres] pruned ${deleted_count} backup(s) older than ${RETENTION_DAYS} days"
echo "[backup_postgres] done"
