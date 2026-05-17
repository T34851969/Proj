#!/usr/bin/env bash
set -e

# Simple wait-for-db using psycopg2 (assumes dependencies installed in image)
if [ -n "$DATABASE_URL" ]; then
  echo "Waiting for database to be ready..."
  python - <<'PY'
import os, time, sys
import psycopg2

dsn = os.environ.get("DATABASE_URL")
if not dsn:
    print("DATABASE_URL not set, skipping wait")
    sys.exit(0)
for i in range(60):
    try:
        conn = psycopg2.connect(dsn)
        conn.close()
        print("Database available")
        sys.exit(0)
    except Exception as e:
        print("db not ready, retrying...", i)
        time.sleep(1)
print("Timed out waiting for the database")
sys.exit(1)
PY
fi

exec "$@"
