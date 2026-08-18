#!/usr/bin/env bash
# Task 7.6: production smoke test for the deployed FastAPI backend.
#
# Deliberately shallow (reachability + contract shape), not a functional
# test — deep correctness is already covered by the pytest suite that runs
# before every deploy. Creates no real user account: auth/sync checks use
# intentionally-invalid credentials/tokens to exercise the same code paths
# (DB, rate limiter, password hasher, auth dependency) without needing
# email verification or any cleanup afterwards.
#
# Usage: BASE_URL=https://116-202-14-23.sslip.io ./prod_smoke_test.sh
# Optional: N8N_WEBHOOK_HMAC_SECRET=... to also exercise the n8n webhook
# (only works once that endpoint is deployed).

set -uo pipefail

BASE_URL="${BASE_URL:-https://116-202-14-23.sslip.io}"
failures=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "[ok]   ${name} (${actual})"
  else
    echo "[FAIL] ${name}: expected ${expected}, got ${actual}"
    failures=$((failures + 1))
  fi
}

echo "== health =="
code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health")
check "GET /health" 200 "$code"

echo "== auth: register (no account is verified/created by this call alone) =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke-test-'"$(date +%s)"'@nonexistent-fiskon-smoketest-domain.net","password":"smoke-test-password-123"}')
check "POST /api/v1/auth/register" 202 "$code"

echo "== auth: login with wrong credentials must fail uniformly =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke-test-nonexistent@nonexistent-fiskon-smoketest-domain.net","password":"wrong-password-123"}')
check "POST /api/v1/auth/login (bad creds)" 401 "$code"

echo "== auth: /me requires a token =="
code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/auth/me")
check "GET /api/v1/auth/me (no token)" 401 "$code"

echo "== sync: pull requires a token =="
code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api/v1/sync/pull")
check "GET /api/v1/sync/pull (no token)" 401 "$code"

echo "== ocr: single minimal parse-receipt call (calls the real Gemini API) =="
response=$(curl -s -o /tmp/smoke_ocr_response.json -w "%{http_code}" -X POST "${BASE_URL}/api/v1/parse-receipt" \
  -H "Content-Type: application/json" \
  -d '{"ocr_text":"MARKET A.S.\nEKMEK 12.50 TL\nTOPLAM 12.50 TL"}')
check "POST /api/v1/parse-receipt" 200 "$response"
if [ "$response" = "200" ]; then
  echo "       response: $(cat /tmp/smoke_ocr_response.json)"
fi

if [ -n "${N8N_WEBHOOK_HMAC_SECRET:-}" ]; then
  echo "== n8n: signed webhook event =="
  body='{"event_type":"group_expense.created","event_id":"'"$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)"'","occurred_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","schema_version":1,"data":{}}'
  ts=$(date +%s)
  sig=$(printf '%s.%s' "$ts" "$body" | openssl dgst -sha256 -hmac "$N8N_WEBHOOK_HMAC_SECRET" | sed 's/^.* //')
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/integrations/n8n/events" \
    -H "Content-Type: application/json" \
    -H "Idempotency-Key: smoke-test-$(date +%s)" \
    -H "X-Webhook-Timestamp: ${ts}" \
    -H "X-Webhook-Signature: sha256=${sig}" \
    -d "$body")
  check "POST /api/v1/integrations/n8n/events (valid signature)" 202 "$code"
else
  echo "== n8n: skipped (N8N_WEBHOOK_HMAC_SECRET not set, or endpoint not deployed yet) =="
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "All smoke checks passed."
  exit 0
else
  echo "${failures} smoke check(s) failed."
  exit 1
fi
