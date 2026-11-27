#!/bin/ash
set -eux
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/root/dnstest" "$TMP/usr/bin" "$TMP/etc/profile.d" "$TMP/backup"
printf 'version-1-preserve\n' > "$TMP/root/dnstest/dns-bench.sh"
printf 'test CA bundle\n' > "$TMP/ca.pem"

cat > "$TMP/bin/id" <<'MOCK'
#!/bin/sh
[ "${1:-}" = -u ] && { echo 0; exit 0; }
exec /usr/bin/id "$@"
MOCK
cat > "$TMP/bin/ash" <<'MOCK'
#!/bin/sh
exec busybox ash "$@"
MOCK
cat > "$TMP/bin/fail-ash" <<'MOCK'
#!/bin/sh
exit 1
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/bin/sh
case "${1:-}" in
  --version) echo 'curl 8.12.0 Protocols: https Features: HTTP2';;
  --help) echo '--noproxy --resolve --next --write-out';;
  *) exit 0;;
esac
MOCK
cat > "$TMP/bin/kdig" <<'MOCK'
#!/bin/sh
exit 0
MOCK
chmod 755 "$TMP/bin/"*

export PATH="$TMP/bin:$PATH"
unset DNSTEST_BASE_URL
export DNSTEST_INSTALL_DIR="$TMP/root/dnstest2"
export DNSTEST_INSTALL_CMD="$TMP/usr/bin/dnstest2"
export DNSTEST_DASHBOARD_PATH="$TMP/etc/profile.d/41-dnstest2-dashboard.sh"
export DNSTEST_BACKUP_ROOT="$TMP/backup"
export DNSTEST_INSTALL_SHELL="$TMP/bin/ash"
export DNSTEST_KDIG="$TMP/bin/kdig"
export DNSTEST_CURL="$TMP/bin/curl"
export DNSTEST_CA_FILE="$TMP/ca.pem"

busybox ash "$ROOT/install.sh"
test -L "$DNSTEST_INSTALL_CMD"
test "$(readlink "$DNSTEST_INSTALL_CMD")" = "$DNSTEST_INSTALL_DIR/dns-bench.sh"
test -x "$DNSTEST_INSTALL_DIR/dns-bench.sh"
test -x "$DNSTEST_INSTALL_DIR/doh-bench.sh"
test -s "$DNSTEST_DASHBOARD_PATH"
busybox ash "$DNSTEST_INSTALL_CMD" --version | grep -q 'v2.0.0'
DNSTEST_DIR="$DNSTEST_INSTALL_DIR" busybox ash "$DNSTEST_INSTALL_CMD" --check | grep -q 'Pre-check: OK'

# A failed post-install pre-check must restore every previous installed file and link.
printf '\n# rollback-fixture\n' >> "$DNSTEST_INSTALL_DIR/dns-bench.sh"
cp -p "$DNSTEST_INSTALL_DIR/dns-bench.sh" "$TMP/before-dns.sh"
cp -p "$DNSTEST_INSTALL_DIR/doh-bench.sh" "$TMP/before-doh.sh"
cp -p "$DNSTEST_DASHBOARD_PATH" "$TMP/before-dashboard.sh"
export DNSTEST_INSTALL_SHELL="$TMP/bin/fail-ash"
if busybox ash "$ROOT/install.sh"; then
  echo 'Expected forced post-install pre-check failure.' >&2
  exit 1
fi
cmp -s "$TMP/before-dns.sh" "$DNSTEST_INSTALL_DIR/dns-bench.sh"
cmp -s "$TMP/before-doh.sh" "$DNSTEST_INSTALL_DIR/doh-bench.sh"
cmp -s "$TMP/before-dashboard.sh" "$DNSTEST_DASHBOARD_PATH"
test -L "$DNSTEST_INSTALL_CMD"
test "$(readlink "$DNSTEST_INSTALL_CMD")" = "$DNSTEST_INSTALL_DIR/dns-bench.sh"

# A successful upgrade backs up the old v2 files before replacing them.
export DNSTEST_INSTALL_SHELL="$TMP/bin/ash"
sleep 1
busybox ash "$ROOT/install.sh"
find "$DNSTEST_BACKUP_ROOT" -type f -name dns-bench.sh -exec grep -l 'rollback-fixture' {} \; | grep -q .
! grep -q 'rollback-fixture' "$DNSTEST_INSTALL_DIR/dns-bench.sh"
grep -q 'version-1-preserve' "$TMP/root/dnstest/dns-bench.sh"

# Uninstall must preserve reports, backups, packages, v1, and unrelated paths.
printf 'preserved-report\n' > "$DNSTEST_INSTALL_DIR/latest-top10.txt"
if command -v script >/dev/null 2>&1; then
  printf 'YES\n' | script -q -e -c "DNSTEST_INSTALL_DIR='$DNSTEST_INSTALL_DIR' DNSTEST_INSTALL_CMD='$DNSTEST_INSTALL_CMD' DNSTEST_DASHBOARD_PATH='$DNSTEST_DASHBOARD_PATH' busybox ash '$ROOT/uninstall.sh'" /dev/null >/dev/null
  test ! -e "$DNSTEST_INSTALL_DIR/dns-bench.sh"
  test ! -e "$DNSTEST_INSTALL_DIR/doh-bench.sh"
  test ! -L "$DNSTEST_INSTALL_CMD"
  test ! -e "$DNSTEST_DASHBOARD_PATH"
  grep -q 'preserved-report' "$DNSTEST_INSTALL_DIR/latest-top10.txt"
else
  echo 'TTY uninstall behavior skipped: util-linux script is unavailable.'
fi
grep -q 'version-1-preserve' "$TMP/root/dnstest/dns-bench.sh"
echo 'Installer rollback, upgrade backup, v1 isolation and uninstall preservation: PASS'
