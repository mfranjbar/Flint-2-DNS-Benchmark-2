#!/bin/ash
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$TMP/bin" "$TMP/app"
cp "$ROOT/doh-bench.sh" "$TMP/app/doh-bench.sh"
chmod 755 "$TMP/app/doh-bench.sh"
printf 'test CA bundle\n' > "$TMP/ca.pem"

cat > "$TMP/bin/kdig" <<'MOCK'
#!/bin/sh
echo ';; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1'
echo ';; Query time: 2 msec'
MOCK
chmod 755 "$TMP/bin/kdig"

cat > "$TMP/bin/curl" <<'MOCK'
#!/bin/sh
case "${1:-}" in
  --version) echo 'curl 8.10.1 fake Protocols: https Features: HTTP2'; exit 0;;
  --help) echo '--noproxy --resolve --next --write-out'; exit 0;;
esac
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"
      id="${out##*.}"
      hi=$((id / 256)); lo=$((id % 256))
      printf "\\$(printf '%03o' "$hi")\\$(printf '%03o' "$lo")\\201\\200\\000\\001\\000\\000\\000\\000\\000\\000" > "$out"
      printf '0.001000|200\n'
      shift 2
      ;;
    -w|--data-binary|-H|--connect-timeout|--max-time|--resolve|--cacert)
      shift 2
      ;;
    https://*) shift;;
    *) shift;;
  esac
done
exit 0
MOCK
chmod 755 "$TMP/bin/curl"

export PATH="$TMP/bin:$PATH"
export DNSTEST_DIR="$TMP/app"
export DNSTEST_KDIG="$TMP/bin/kdig"
export DNSTEST_CURL="$TMP/bin/curl"
export DNSTEST_CA_FILE="$TMP/ca.pem"
export DNSTEST_PUBLIC_SERVERS='Public-A|192.0.2.10
Public-B|192.0.2.11'
export DNSTEST_IRAN_SERVERS='Iran-A|192.0.2.20
Iran-B|192.0.2.21'
export DNSTEST_DOT_SERVERS='Dot-A|192.0.2.30|dot-a.example
Dot-B|192.0.2.31|dot-b.example'
export DNSTEST_DOH_SERVERS='Doh-A|192.0.2.40|doh-a.example|/dns-query|GET
Doh-B|192.0.2.41|doh-b.example|/dns-query|GET'

busybox ash "$ROOT/dns-bench.sh" --check
busybox ash "$ROOT/dns-bench.sh" > "$TMP/run.txt"
REPORT="$TMP/app/latest-top10.txt"
test -s "$REPORT"
test "$(grep -Ec '^[[:space:]]*[0-9]+[[:space:]]' "$REPORT")" -eq 10
awk '
/^[[:space:]]*[0-9]+[[:space:]]/ {
  n++
  if ($1 != n) exit 1
  if (n==1 && $5!="TCP") exit 1
  if (n==2 && $5!="TCP") exit 1
  if (n==3 && $5!="UDP") exit 1
  if (n==4 && $5!="UDP") exit 1
  if (n==5 && $5!="DOT") exit 1
  if (n==6 && $5!="DOT") exit 1
  if (n==7 && $5!="DoH") exit 1
  if (n==8 && $5!="DoH") exit 1
  if (n>=9 && $5!="UDP" && $5!="TCP") exit 1
}
END { if (n != 10) exit 1 }
' "$REPORT"
grep -q 'Iran-A\|Iran-B' "$REPORT"
echo 'Mocked end-to-end v2 orchestration and exact 10-row ordering: PASS'
