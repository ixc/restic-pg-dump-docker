#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_BASE_DIR="$ROOT_DIR/.superpowers/sdd"
mkdir -p "$TMP_BASE_DIR"
TMP_DIR="$TMP_BASE_DIR/backup-excluded-databases-$$-$RANDOM"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/setup.sh" <<'EOF'
#!/usr/bin/env bash
:
EOF
chmod +x "$TMP_DIR/setup.sh"

cat > "$TMP_DIR/psql" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-l" ]]; then
  exit 0
fi
if [[ "${1:-}" == "-d" && "${2:-}" == "postgres" ]]; then
  printf '%s\n' "$*" > "${TEST_QUERY_FILE:?}"
  printf 'app_keep\napp_exclude\n'
  exit 0
fi
exit 1
EOF
chmod +x "$TMP_DIR/psql"

cat > "$TMP_DIR/pg_dump" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dump_file=""
for arg in "$@"; do
  if [[ "$arg" == --file=* ]]; then
    dump_file="${arg#--file=}"
  fi
  if [[ "$arg" == --dbname=* ]]; then
    printf '%s\n' "${arg#--dbname=}" >> "${TEST_DUMP_FILE:?}"
  fi
done
if [[ -n "$dump_file" ]]; then
  printf 'dump\n' > "$dump_file"
fi
exit 0
EOF
chmod +x "$TMP_DIR/pg_dump"

cat > "$TMP_DIR/restic" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$TMP_DIR/restic"

export TEST_QUERY_FILE="$TMP_DIR/query.txt"
export TEST_DUMP_FILE="$TMP_DIR/dumped.txt"
touch "$TEST_DUMP_FILE"

# Ensure tests run in this environment by using a writable dump directory
export PG_DUMP_DIR="$TMP_DIR/pg_dump_dir"
mkdir -p "$PG_DUMP_DIR"
printf 'keep\n' > "$PG_DUMP_DIR/keep.me"

(
  cd "$ROOT_DIR"
  PATH="$TMP_DIR:$PATH" \
  PGHOST_1="db.example.internal" \
  PGPASSWORD_1="secret" \
  PGUSER_1="postgres" \
  EXCLUDED_DATABASES="app_exclude" \
  bash bin/backup.sh >/dev/null 2>&1
)

if grep -qx 'app_exclude' "$TEST_DUMP_FILE"; then
  echo "FAIL: expected app_exclude to be skipped"
  exit 1
fi
if ! grep -qx 'app_keep' "$TEST_DUMP_FILE"; then
  echo "FAIL: expected app_keep to be dumped"
  exit 1
fi
if [[ ! -f "$PG_DUMP_DIR/keep.me" ]]; then
  echo "FAIL: expected sentinel file to survive cleanup"
  exit 1
fi
if find "$PG_DUMP_DIR" -maxdepth 1 -type f -name '*.sql' | grep -q .; then
  echo "FAIL: expected generated dump files to be cleaned up"
  exit 1
fi
echo "PASS: global exclusions verified"

: > "$TEST_DUMP_FILE"
(
  cd "$ROOT_DIR"
  PATH="$TMP_DIR:$PATH" \
  PGHOST_1="db.example.internal" \
  PGPASSWORD_1="secret" \
  PGUSER_1="postgres" \
  EXCLUDED_DATABASES="app_keep" \
  EXCLUDED_DATABASES_1="app_exclude" \
  bash bin/backup.sh >/dev/null 2>&1
)

if grep -qx 'app_exclude' "$TEST_DUMP_FILE"; then
  echo "FAIL: expected app_exclude to be skipped by EXCLUDED_DATABASES_1"
  exit 1
fi
if ! grep -qx 'app_keep' "$TEST_DUMP_FILE"; then
  echo "FAIL: expected app_keep to be dumped when EXCLUDED_DATABASES_1 overrides global"
  exit 1
fi
if [[ ! -f "$PG_DUMP_DIR/keep.me" ]]; then
  echo "FAIL: expected sentinel file to survive cleanup"
  exit 1
fi
if find "$PG_DUMP_DIR" -maxdepth 1 -type f -name '*.sql' | grep -q .; then
  echo "FAIL: expected generated dump files to be cleaned up"
  exit 1
fi
echo "PASS: per-cluster override verified"
