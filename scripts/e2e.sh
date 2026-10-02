#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
web_port="${WEB_PORT:-8090}"
secret() { openssl rand -hex 16; }

if [[ -n "${ADMIN_PASSWORD_HASH:-}" && -z "${ADMIN_PASSWORD:-}" ]]; then
  echo "ADMIN_PASSWORD is required when ADMIN_PASSWORD_HASH is set" >&2
  exit 1
fi

export LANG="${LANG:-C.UTF-8}"
export DB_PASSWORD="${DB_PASSWORD:-$(secret)}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-$(secret)}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-$(secret)}"
export REPORTER_KEY="${REPORTER_KEY:-$(secret)}"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(secret)}"
export CORS_ALLOWED_ORIGINS="http://localhost:${web_port}"
export SPRING_PROFILES_ACTIVE=demo
export TRUSTED_PROXIES_REGEX='172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}'

if [[ -z "${ADMIN_PASSWORD_HASH:-}" ]]; then
  ADMIN_PASSWORD_HASH="$(printf '%s' "$ADMIN_PASSWORD" | htpasswd -niBC 10 "" | tr -d ':\n')"
fi
export ADMIN_PASSWORD_HASH

compose() { docker compose -f "$root/docker-compose.yml" "$@"; }

cleanup() {
  local status=$?
  [[ -n "${web_pid:-}" ]] && kill "$web_pid" 2>/dev/null || true
  if [[ $status -ne 0 ]]; then
    mkdir -p "$root/e2e/test-results"
    compose logs --no-color > "$root/e2e/test-results/compose.log" 2>&1 || true
    compose ps -a >&2 || true
    tail -n 80 "$root/e2e/test-results/compose.log" >&2 || true
  fi
  if [[ "${KEEP_STACK:-false}" != "true" ]]; then
    compose down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  exit $status
}
trap cleanup EXIT

(cd "$root/server" && ./gradlew --no-daemon -q bootJar)
compose up -d --build --wait

(cd "$root/app" && flutter pub get >/dev/null \
  && dart run build_runner build --delete-conflicting-outputs >/dev/null \
  && flutter build web --release --no-web-resources-cdn \
    --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=TILE_URL_TEMPLATE=)

python3 -m http.server "$web_port" --bind 127.0.0.1 --directory "$root/app/build/web" >/dev/null 2>&1 &
web_pid=$!
for _ in $(seq 1 50); do
  curl -sf "http://localhost:${web_port}/" >/dev/null && break
  sleep 0.2
done
curl -sf "http://localhost:${web_port}/" >/dev/null

cd "$root/e2e"
if [[ ! -d node_modules || package-lock.json -nt node_modules ]]; then
  npm ci --no-audit --no-fund
fi
APP_URL="http://localhost:${web_port}" API_URL="http://localhost:8080" npx playwright test "$@"
