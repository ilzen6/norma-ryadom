#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
web_port="${WEB_PORT:-8090}"
export LANG="${LANG:-C.UTF-8}"
export DB_PASSWORD="${DB_PASSWORD:-e2e-db-$RANDOM$RANDOM}"
export S3_ACCESS_KEY="${S3_ACCESS_KEY:-e2e-key-$RANDOM}"
export S3_SECRET_KEY="${S3_SECRET_KEY:-e2e-secret-$RANDOM$RANDOM}"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-e2e-admin-$RANDOM$RANDOM}"
export CORS_ALLOWED_ORIGINS="http://localhost:${web_port}"
export SPRING_PROFILES_ACTIVE=demo

if [[ -z "${ADMIN_PASSWORD_HASH:-}" ]]; then
  ADMIN_PASSWORD_HASH="$(htpasswd -nbBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n')"
fi
export ADMIN_PASSWORD_HASH

cleanup() {
  [[ -n "${web_pid:-}" ]] && kill "$web_pid" 2>/dev/null || true
  if [[ "${KEEP_STACK:-false}" != "true" ]]; then
    docker compose -f "$root/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

(cd "$root/server" && ./gradlew --no-daemon -q bootJar)
docker compose -f "$root/docker-compose.yml" up -d --build --wait

(cd "$root/app" && flutter pub get >/dev/null \
  && dart run build_runner build --delete-conflicting-outputs >/dev/null \
  && flutter build web --release --no-web-resources-cdn \
    --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=TILE_URL_TEMPLATE=)

python3 -m http.server "$web_port" --bind 127.0.0.1 --directory "$root/app/build/web" >/dev/null 2>&1 &
web_pid=$!

cd "$root/e2e"
npm ci --no-audit --no-fund
APP_URL="http://localhost:${web_port}" API_URL="http://localhost:8080" npx playwright test "$@"
