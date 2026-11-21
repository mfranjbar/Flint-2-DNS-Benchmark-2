#!/bin/ash
# FLINT 2 DNS BENCHMARK v2
# Independent installation and report; does not touch v1.
set -u
DIR="${DNSTEST_DIR:-/root/dnstest2}"
REPORT="$DIR/latest-top10.txt"
LOCK='/tmp/flint-dnstest2.lock'
KDIG="${DNSTEST_KDIG:-/usr/bin/kdig}"
VERSION='2.0.0'
ROUNDS=2
QUERY_TIMEOUT=3
DOT_TIMEOUT=4
HARD_LIMIT=8
DOMAINS='github.com nasa.gov openwrt.org'
CA_FILE="${DNSTEST_CA_FILE:-/etc/ssl/cert.pem}"
[ -s "$CA_FILE" ] || { [ -n "${DNSTEST_CA_FILE:-}" ] || CA_FILE='/etc/ssl/certs/ca-certificates.crt'; }

PUBLIC_SERVERS='
Cloudflare|1.1.1.1
Cloudflare-Secondary|1.0.0.1
Cloudflare-Security|1.1.1.2
Google|8.8.8.8
Google-Secondary|8.8.4.4
Level3|4.2.2.2
Level3-Secondary|4.2.2.4
Quad9|9.9.9.9
Quad9-Secondary|149.112.112.112
Quad9-Unfiltered|9.9.9.10
Quad9-Unfiltered-Secondary|149.112.112.10
Quad9-ECS-Secure|9.9.9.11
Quad9-ECS-Secure-Secondary|149.112.112.11
Quad9-ECS-Unfiltered|9.9.9.12
Quad9-ECS-Unfiltered-Secondary|149.112.112.12
OpenDNS|208.67.222.222
OpenDNS-Secondary|208.67.220.220
AdGuard|94.140.14.14
AdGuard-Secondary|94.140.15.15
ControlD-Unfiltered|76.76.2.0
ControlD-Unfiltered-Secondary|76.76.10.0
DNS-WATCH|84.200.69.80
DNS-WATCH-Secondary|84.200.70.40
Verisign|64.6.64.6
Verisign-Secondary|64.6.65.6
DNS-SB|185.222.222.222
DNS-SB-Secondary|45.11.45.11
'

IRAN_SERVERS='
Electro-Primary|78.157.42.100
Electro-Secondary|78.157.42.101
Begzar-Primary|185.55.226.26
Begzar-Secondary|185.55.225.25
Shecan-Primary|178.22.122.100
Shecan-Secondary|185.51.200.2
IPM-Primary|194.225.152.10
IPM-Secondary|194.225.152.12
TIC|2.189.1.1
'

DOT_SERVERS='
Cloudflare-DoT|1.1.1.1|cloudflare-dns.com
Cloudflare-Secondary-DoT|1.0.0.1|cloudflare-dns.com
Google-DoT|8.8.8.8|dns.google
Google-Secondary-DoT|8.8.4.4|dns.google
Quad9-DoT|9.9.9.9|dns.quad9.net
Quad9-Secondary-DoT|149.112.112.112|dns.quad9.net
AdGuard-DoT|94.140.14.14|dns.adguard-dns.com
AdGuard-Secondary-DoT|94.140.15.15|dns.adguard-dns.com
LibreDNS-DoT|116.202.176.26|dot.libredns.gr
Mullvad-DoT|194.242.2.2|dns.mullvad.net
DNS-SB-DoT|185.222.222.222|dot.sb
DNS-SB-Secondary-DoT|45.11.45.11|dot.sb
ControlD-Unfiltered-DoT|76.76.2.0|p0.freedns.controld.com
'

# Optional test fixtures; production defaults remain the full resolver lists.
PUBLIC_SERVERS="${DNSTEST_PUBLIC_SERVERS:-$PUBLIC_SERVERS}"
IRAN_SERVERS="${DNSTEST_IRAN_SERVERS:-$IRAN_SERVERS}"
DOT_SERVERS="${DNSTEST_DOT_SERVERS:-$DOT_SERVERS}"

TMP="/tmp/flint-dnstest2-$"
RAW="$TMP.classic"
IRAW="$TMP.iran"
DRAW="$TMP.doh"
REPORT_TMP="$TMP.report"
say() { printf '%s\n' "$*"; }
fail() { say "ERROR: $*" >&2; exit 1; }
cleanup() {
  rm -f "$RAW" "$IRAW" "$DRAW" "$REPORT_TMP" "$TMP".*
  rmdir "$TMP" 2>/dev/null
  rmdir "$LOCK" 2>/dev/null
}
check_deps() {
  for c in awk grep sort head sed date mkdir rmdir rm mv cat timeout; do
    command -v "$c" >/dev/null 2>&1 || { say "Missing command: $c"; return 1; }
  done
  [ -x "$KDIG" ] || { say "Missing /usr/bin/kdig (package knot-dig)"; return 1; }
  timeout 1 sh -c 'exit 0' >/dev/null 2>&1 || { say 'timeout is unavailable'; return 1; }
  [ -s "$CA_FILE" ] || { say 'CA bundle missing (install ca-bundle)'; return 1; }
  command -v curl >/dev/null 2>&1 || { say 'curl is missing'; return 1; }
  curl --version 2>&1 | grep -qi https || { say 'curl has no HTTPS/TLS'; return 1; }
  curl --help all 2>&1 | grep -q -- '--resolve' || { say 'curl lacks --resolve'; return 1; }
  curl --help all 2>&1 | grep -q -- '--next' || { say 'curl lacks --next'; return 1; }
  for c in base64 od tr wc; do command -v "$c" >/dev/null 2>&1 || { say "Missing command: $c"; return 1; }; done
  [ -d "$DIR" ] && [ -w "$DIR" ] || { say "Directory not writable: $DIR"; return 1; }
  DNSTEST_DIR="$DIR" sh "$DIR/doh-bench.sh" --check >/dev/null 2>&1 || { say 'DoH prerequisite check failed; run doh-bench.sh --check for details.'; return 1; }
  return 0
}
get_ms() {
  printf '%s\n' "$1" | sed -n -e 's/.* in \([0-9][0-9.]*\) ms.*/\1/p' -e 's/.*Query time: \([0-9][0-9.]*\) msec.*/\1/p' | head -n 1
}
query_plain() {
  QIP="$1"; QDOMAIN="$2"; QTYPE="$3"
  if [ "$QTYPE" = UDP ]; then MODE='+notcp'; else MODE='+tcp'; fi
  QOUT="$(timeout "$HARD_LIMIT" "$KDIG" "@$QIP" "$QDOMAIN" A "$MODE" "+timeout=$QUERY_TIMEOUT" +retry=0 +stats 2>&1)"
  QRC=$?
  QUERY_OK=0; QUERY_MS=''
  if [ "$QRC" -eq 0 ] && printf '%s\n' "$QOUT" | grep -Eq 'status: (NOERROR|NXDOMAIN)'; then
    QUERY_MS="$(get_ms "$QOUT")"
    case "$QUERY_MS" in ''|*[!0-9.]*) QUERY_MS='';; *) QUERY_OK=1;; esac
  fi
}
query_dot() {
  QIP="$1"; QHOST="$2"; QDOMAIN="$3"
  QOUT="$(timeout "$HARD_LIMIT" "$KDIG" "@$QIP" "$QDOMAIN" A +tls "+tls-ca=$CA_FILE" "+tls-hostname=$QHOST" "+timeout=$DOT_TIMEOUT" +retry=0 +stats 2>&1)"
  QRC=$?
  QUERY_OK=0; QUERY_MS=''
  if [ "$QRC" -eq 0 ] && printf '%s\n' "$QOUT" | grep -Eq 'status: (NOERROR|NXDOMAIN)'; then
    QUERY_MS="$(get_ms "$QOUT")"
    case "$QUERY_MS" in ''|*[!0-9.]*) QUERY_MS='';; *) QUERY_OK=1;; esac
  fi
}
score_server() {
  SNAME="$1"; SIP="$2"; STYPE="$3"; TARGET="$4"; OUTFILE="$5"
  # One unscored warm-up query per domain, following the reference methodology.
  for DOMAIN in $DOMAINS; do
    if [ "$STYPE" = DOT ]; then query_dot "$SIP" "$TARGET" "$DOMAIN"; else query_plain "$SIP" "$DOMAIN" "$STYPE"; fi
  done
  OK=0; TOTAL=0; SUM='0'; ROUND=1
  while [ "$ROUND" -le "$ROUNDS" ]; do
    for DOMAIN in $DOMAINS; do
      TOTAL=$((TOTAL+1))
      if [ "$STYPE" = DOT ]; then query_dot "$SIP" "$TARGET" "$DOMAIN"; else query_plain "$SIP" "$DOMAIN" "$STYPE"; fi
      if [ "$QUERY_OK" -eq 1 ]; then
        OK=$((OK+1))
        SUM="$(awk -v a="$SUM" -v b="$QUERY_MS" 'BEGIN { printf "%.4f", a+b }')"
      else
        SUM="$(awk -v a="$SUM" 'BEGIN { printf "%.4f", a+5000 }')"
      fi
    done
    ROUND=$((ROUND+1))
  done
  AVG="$(awk -v s="$SUM" -v n="$TOTAL" 'BEGIN { printf "%.1f", s/n }')"
  [ "$OK" -eq 0 ] || printf '%s|%s|%s|%s|%s/%s\n' "$AVG" "$SNAME" "$SIP" "$STYPE" "$OK" "$TOTAL" >> "$OUTFILE"
}
run_classic_group() {
  SERVERS="$1"; TYPES="$2"; OUTFILE="$3"
  printf '%s\n' "$SERVERS" > "$TMP.servers"
  while IFS='|' read -r NAME IP; do
    [ -n "$NAME" ] || continue
    for TYPE in $TYPES; do
      say "Testing $NAME / $TYPE"
      score_server "$NAME" "$IP" "$TYPE" '' "$OUTFILE"
    done
  done < "$TMP.servers"
}
top_two() {
  TTYPE="$1"; TFILE="$2"
  awk -F'|' -v t="$TTYPE" '$4==t {print}' "$TFILE" | sort -t '|' -k1,1n | head -n 2
}
render_report() {
  printf '%s\n' '=============================================================='
  printf '%s\n' '             DNS BENCHMARK / FLINT 2 v2'
  printf '%s\n' '=============================================================='
  printf '%-2s %-26s %-9s %-15s %-5s %s\n' '#' DNS AVG IP TYPE OK
  printf '%s\n' '--------------------------------------------------------------'
  N=0
  for GROUP in TCP UDP DOT DOH; do
    if [ "$GROUP" = DOH ]; then
      SRC="$DRAW"
    else
      SRC="$RAW"
    fi
    if [ "$GROUP" = DOT ]; then
      LINES="$(top_two DOT "$SRC")"
    elif [ "$GROUP" = DOH ]; then
      LINES="$(awk -F'|' '{print $1 "|" $7 "|" $6 "|DoH|" $5}' "$SRC" | sort -t '|' -k1,1n | head -n 2)"
    else
      LINES="$(top_two "$GROUP" "$SRC")"
    fi
    if [ -n "$LINES" ]; then
      while IFS='|' read -r AVG NAME IP TYPE OK; do
        [ -n "$NAME" ] || continue
        N=$((N+1))
        printf '%-2s %-26.26s %-9s %-15s %-5s %s\n' "$N" "$NAME" "$AVG" "$IP" "$TYPE" "$OK"
      done <<EOF2
$LINES
EOF2
    fi
  done
  IRLINES="$(sort -t '|' -k1,1n "$IRAW" | awk -F'|' '!seen[$3]++ { print; n++; if (n==2) exit }')"
  if [ -n "$IRLINES" ]; then
    while IFS='|' read -r AVG NAME IP TYPE OK; do
      [ -n "$NAME" ] || continue
      N=$((N+1))
      printf '%-2s %-26.26s %-9s %-15s %-5s %s\n' "$N" "$NAME" "$AVG" "$IP" "$TYPE" "$OK"
    done <<EOF2
$IRLINES
EOF2
  fi
  printf '%s\n' '--------------------------------------------------------------'
  printf 'Last test: %s\n' "$LAST_TEST"
}
case "${1:-}" in
  --version) say "Flint 2 DNS Benchmark v$VERSION"; exit 0 ;;
  --help) say 'Usage: dnstest2 [--version|--check|--help]'; exit 0 ;;
  --check) mkdir -p "$DIR" || exit 1; check_deps || exit 1; say 'Pre-check: OK (no DNS queries sent)'; exit 0 ;;
esac
[ "$#" -eq 0 ] || fail 'Unknown argument. Use --help.'
mkdir -p "$DIR" || fail "Cannot create $DIR"
check_deps || exit 1
mkdir "$LOCK" 2>/dev/null || fail 'Another v2 benchmark is running.'
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
mkdir "$TMP" || fail 'Cannot create temporary directory.'
: > "$RAW"; : > "$IRAW"; : > "$DRAW"
say 'Starting UDP/TCP public DNS tests (1 warm-up + 2 measured rounds)...'
run_classic_group "$PUBLIC_SERVERS" 'UDP TCP' "$RAW"
say 'Starting Iranian DNS tests (UDP and TCP)...'
run_classic_group "$IRAN_SERVERS" 'UDP TCP' "$IRAW"
say 'Starting DNS-over-TLS tests (1 warm-up + 2 measured rounds)...'
printf '%s\n' "$DOT_SERVERS" > "$TMP.dotservers"
while IFS='|' read -r NAME IP HOST; do
  [ -n "$NAME" ] || continue
  say "Testing $NAME / DoT"
  score_server "$NAME" "$IP" DOT "$HOST" "$RAW"
done < "$TMP.dotservers"
say 'Starting DNS-over-HTTPS tests (all configured providers)...'
DNSTEST_DIR="$DIR" DNSTEST_RAW_OUT="$DRAW" sh "$DIR/doh-bench.sh" >/dev/null || fail 'DoH benchmark failed; previous final report preserved.'
[ -s "$DRAW" ] || fail 'No DoH raw results were exported.'
LAST_TEST="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_TMP="$TMP.report"
render_report > "$REPORT_TMP" || fail 'Could not render report.'
[ "$(grep -Ec '^[[:space:]]*[0-9]+[[:space:]]' "$REPORT_TMP")" -eq 10 ] || fail 'Expected exactly 10 result rows; previous report preserved.'
mv -f "$REPORT_TMP" "$REPORT" || fail 'Could not replace final report.'
cat "$REPORT"
say "Report saved: $REPORT"
exit 0
