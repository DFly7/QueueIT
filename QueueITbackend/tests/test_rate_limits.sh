#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# test_rate_limits.sh
#
# Usage:
#   ./tests/test_rate_limits.sh <JWT_USER_A> <JWT_USER_B>
#
# Fires requests in parallel so they all land within the same 1-second burst
# window. Sequential curl is too slow to trigger per-second limits.
# ---------------------------------------------------------------------------

set -euo pipefail

BASE="http://localhost:8000"
JWT_A="${1:-}"
JWT_B="${2:-}"

GREEN="\033[0;32m"; RED="\033[0;31m"; CYAN="\033[0;36m"; YELLOW="\033[0;33m"; RESET="\033[0m"

pass()  { echo -e "  ${GREEN}✓ PASS${RESET}  $1"; }
fail()  { echo -e "  ${RED}✗ FAIL${RESET}  $1"; FAILURES=$((FAILURES + 1)); }
info()  { echo -e "${CYAN}▶ $1${RESET}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${RESET}"; }
FAILURES=0

# ── Preflight ────────────────────────────────────────────────────────────────
if [[ -z "$JWT_A" || -z "$JWT_B" ]]; then
  echo "Usage: $0 <JWT_USER_A> <JWT_USER_B>"
  exit 1
fi

if ! curl -sf "${BASE}/healthz" > /dev/null 2>&1; then
  echo -e "${RED}ERROR: Server not reachable at ${BASE}${RESET}"
  exit 1
fi

# ── Parallel burst helper ─────────────────────────────────────────────────────
# Fire N requests all at once (background curl jobs).
# Prints all status codes, space-separated.
burst() {
  local n=$1 method=$2 url=$3; shift 3
  local tmp; tmp=$(mktemp -d)
  for ((i=1; i<=n; i++)); do
    curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" "$@" \
      > "${tmp}/${i}" &
  done
  wait
  local codes=()
  for ((i=1; i<=n; i++)); do codes+=("$(cat "${tmp}/${i}")"); done
  rm -rf "$tmp"
  echo "${codes[*]}"
}

# Returns 0 (true) if any code in the list equals 429
any_429()   { for c in "$@"; do [[ "$c" == "429" ]] && return 0; done; return 1; }
# Returns 0 (true) if NO code in the list equals 429
none_429()  { for c in "$@"; do [[ "$c" == "429" ]] && return 1; done; return 0; }

A=(-H "Authorization: Bearer $JWT_A")
B=(-H "Authorization: Bearer $JWT_B")
J=(-H "Content-Type: application/json")

echo ""
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  QueueIT Rate Limit Smoke Tests              ${RESET}"
echo -e "${CYAN}  Target: ${BASE}                             ${RESET}"
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""

# ── 1. /healthz exempt ───────────────────────────────────────────────────────
info "1. /healthz — exempt from all rate limiting"
read -ra codes <<< "$(burst 15 GET "${BASE}/healthz")"
if none_429 "${codes[@]}"; then
  pass "15 parallel requests to /healthz — none rate-limited (${codes[*]})"
else
  fail "/healthz returned 429 — should be exempt (${codes[*]})"
fi
echo ""

# ── Endpoint test helper ──────────────────────────────────────────────────────
# test_endpoint <label> <burst_cap> <method> <url> [curl_args...]
#
# 1. Fires burst_cap requests in parallel for User A → expects none are 429
# 2. Fires one more for User A                       → expects 429
# 3. Fires one for User B                            → expects NOT 429
test_endpoint() {
  local label=$1 cap=$2 method=$3 url=$4; shift 4

  # Step 1: within-burst for User A
  read -ra within <<< "$(burst "$cap" "$method" "$url" "${A[@]}" "$@")"
  if none_429 "${within[@]}"; then
    pass "${label}: ${cap} parallel requests within burst — none 429 (${within[*]})"
  else
    fail "${label}: ${cap} requests within burst — unexpected 429 (${within[*]})"
  fi

  # Step 2: one more for User A should now be 429
  over=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" "${A[@]}" "$@")
  if [[ "$over" == "429" ]]; then
    pass "${label}: burst+1 request → 429 ✓"
  else
    fail "${label}: burst+1 request → expected 429 but got $over"
  fi

  # Step 3: User B should not be affected
  iso=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" "${B[@]}" "$@")
  if [[ "$iso" != "429" ]]; then
    pass "${label}: User B unaffected by User A's limit (got $iso)"
  else
    fail "${label}: User B got 429 — per-user isolation broken"
  fi
}

# ── 2. Spotify search (5/second) ─────────────────────────────────────────────
info "2. GET /api/v1/spotify/search — 20/min ; 5/second burst"
test_endpoint "spotify/search" 5 GET \
  "${BASE}/api/v1/spotify/search?q=test"
echo ""

# ── 3. Sessions join (5/second) ───────────────────────────────────────────────
info "3. POST /api/v1/sessions/join — 20/min ; 5/second burst"
test_endpoint "sessions/join" 5 POST \
  "${BASE}/api/v1/sessions/join" \
  "${J[@]}" -d '{"join_code":"ZZZZ99"}'
echo ""

# ── 4. Sessions create (3/second) ─────────────────────────────────────────────
info "4. POST /api/v1/sessions/create — 10/min ; 3/second burst"
test_endpoint "sessions/create" 3 POST \
  "${BASE}/api/v1/sessions/create" \
  "${J[@]}" -d '{"join_code":"TSTCODE1"}'
echo ""

# ── 5. Songs add (5/second) ────────────────────────────────────────────────────
info "5. POST /api/v1/songs/add — 30/min ; 5/second burst"
ADD_BODY='{"id":"spotify:track:abc","isrc":"US-QW-00-000001","name":"Test","artists":"Artist","album":"Album","duration_ms":180000,"image_url":"https://i.scdn.co/image/ab67616d0000b273af62372ee43fe1e854d0bce5","source":"spotify"}'
test_endpoint "songs/add" 5 POST \
  "${BASE}/api/v1/songs/add" \
  "${J[@]}" -d "$ADD_BODY"
echo ""

# ── 6. Songs vote (5/second) ───────────────────────────────────────────────────
info "6. POST /api/v1/songs/{id}/vote — 60/min ; 5/second burst"
test_endpoint "songs/vote" 5 POST \
  "${BASE}/api/v1/songs/00000000-0000-0000-0000-000000000001/vote" \
  "${J[@]}" -d '{"vote_value":1}'
echo ""

# ── 7. 429 response shape ──────────────────────────────────────────────────────
info "7. 429 response shape"
# Search endpoint should still be limited for User A from test 2
RESP=$(curl -s -X GET "${BASE}/api/v1/spotify/search?q=test" "${A[@]}")
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET "${BASE}/api/v1/spotify/search?q=test" "${A[@]}")

if [[ "$STATUS" != "429" ]]; then
  warn "Search endpoint no longer rate-limited for User A (got $STATUS) — skipping shape test"
  warn "This can happen if enough time passed for the window to reset"
else
  if echo "$RESP" | grep -q '"error"' \
    && echo "$RESP" | grep -q '"status_code"' \
    && echo "$RESP" | grep -q '"request_id"'; then
    pass "429 body contains error, status_code, request_id"
  else
    fail "429 body missing expected fields — got: $RESP"
  fi

  HEADERS=$(curl -sI -X GET "${BASE}/api/v1/spotify/search?q=test" "${A[@]}")
  if echo "$HEADERS" | grep -qi "^X-Request-ID:"; then
    pass "429 response includes X-Request-ID header"
  else
    warn "X-Request-ID not found in headers (may be a curl -I issue)"
  fi

  if echo "$HEADERS" | grep -qi "^Retry-After:"; then
    pass "429 response includes Retry-After header"
  else
    warn "Retry-After header not present (best-effort — only set when expiry is available)"
  fi
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}  All tests passed ✓${RESET}"
else
  echo -e "${RED}  $FAILURES test(s) failed${RESET}"
fi
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""

exit $FAILURES
