#!/bin/ash
set -eux
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/root/dnstest" "$TMP/usr/bin" "$TMP/etc/profile.d" "$TMP/backup"
cat > "$TMP/root/dnstest/dns-bench.sh" <<'V1SCRIPT'
#!/bin/ash
# FLINT 2 DNS BENCHMARK
DIR="/root/dnstest"
REPORT="$DIR/latest-top4.txt"
V1SCRIPT
cat > "$TMP/etc/profile.d/40-dnstest-dashboard.sh" <<'V1DASH'
#!/bin/ash
# Flint 2 - DNS benchmark SSH dashboard
REPORT="/root/dnstest/latest-top4.txt"
V1DASH
printf 'preserved-v1-report\n' > "$TMP/root/dnstest/latest-top4.txt"
ln -s "$TMP/root/dnstest/dns-bench.sh" "$TMP/usr/bin/dnstest"
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
export DNSTEST_V1_DIR="$TMP/root/dnstest"
export DNSTEST_V1_CMD="$TMP/usr/bin/dnstest"
export DNSTEST_V1_DASHBOARD_PATH="$TMP/etc/profile.d/40-dnstest-dashboard.sh"
export DNSTEST_INSTALL_SHELL="$TMP/bin/ash"
export DNSTEST_KDIG="$TMP/bin/kdig"
export DNSTEST_CURL="$TMP/bin/curl"
export DNSTEST_CA_FILE="$TMP/ca.pem"

# A failed first install must restore every recognized v1 artifact and keep reports.
export DNSTEST_INSTALL_SHELL="$TMP/bin/fail-ash"
if busybox ash "$ROOT/install.sh"; then
  echo 'Expected forced first-install pre-check failure.' >&2
  exit 1
fi
test -f "$DNSTEST_V1_DIR/dns-bench.sh"
test -L "$DNSTEST_V1_CMD"
test -f "$DNSTEST_V1_DASHBOARD_PATH"
grep -q 'preserved-v1-report' "$DNSTEST_V1_DIR/latest-top4.txt"
test ! -e "$DNSTEST_INSTALL_DIR/dns-bench.sh"
test ! -L "$DNSTEST_INSTALL_CMD"

# Successful install migrates recognized v1 files but retains reports and data directory.
export DNSTEST_INSTALL_SHELL="$TMP/bin/ash"
busybox ash "$ROOT/install.sh"
test -L "$DNSTEST_INSTALL_CMD"
test "$(readlink "$DNSTEST_INSTALL_CMD")" = "$DNSTEST_INSTALL_DIR/dns-bench.sh"
test -x "$DNSTEST_INSTALL_DIR/dns-bench.sh"
test -x "$DNSTEST_INSTALL_DIR/doh-bench.sh"
test -s "$DNSTEST_DASHBOARD_PATH"
busybox ash "$DNSTEST_INSTALL_CMD" --version | grep -q 'v2.0.0'
DNSTEST_DIR="$DNSTEST_INSTALL_DIR" busybox ash "$DNSTEST_INSTALL_CMD" --check | grep -q 'Pre-check: OK'
test ! -e "$DNSTEST_V1_DIR/dns-bench.sh"
test ! -L "$DNSTEST_V1_CMD"
test ! -e "$DNSTEST_V1_DASHBOARD_PATH"
test -d "$DNSTEST_V1_DIR"
grep -q 'preserved-v1-report' "$DNSTEST_V1_DIR/latest-top4.txt"
find "$DNSTEST_BACKUP_ROOT" -type f -name v1-dns-bench.sh | grep -q .
find "$DNSTEST_BACKUP_ROOT" -type f -name v1-dashboard.sh | grep -q .
find "$DNSTEST_BACKUP_ROOT" -type l -name v1-command-link | grep -q .

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
grep -q 'preserved-v1-report' "$DNSTEST_V1_DIR/latest-top4.txt"

# Uninstall must preserve reports, backups, packages, v1, and unrelated paths.
printf 'preserved-report\n' > "$DNSTEST_INSTALL_DIR/latest-top10.txt"
if command -v script >/dev/null 2>&1; then
  printf 'YES\n' | script -q -e -c "DNSTEST_INSTALL_DIR='$DNSTEST_INSTALL_DIR' DNSTEST_INSTALL_CMD='$DNSTEST_INSTALL_CMD' DNSTEST_DASHBOARD_PATH='$DNSTEST_DASHBOARD_PATH' busybox ash '$ROOT/uninstall.sh'" /dev/null >/dev/null
  test ! -e "$DNSTEST_INSTALL_DIR/dns-bench.sh"
  test ! -e "$DNSTEST_INSTALL_DIR/doh-bench.sh"
  test ! -L "$DNSTEST_INSTALL_CMD"
  test ! -e "$DNSTEST_DASHBOARD_PATH"
  grep -q 'preserved-report' "$DNSTEST_INSTALL_DIR/latest-top10.txt"

  # A symlinked install directory must be rejected without touching its target.
  mkdir -p "$TMP/outside-v2"
  printf '# FLINT 2 DNS BENCHMARK v2\\n' > "$TMP/outside-v2/dns-bench.sh"
  ln -s "$TMP/outside-v2" "$TMP/symlink-v2"
  if printf 'YES\\n' | script -q -e -c "DNSTEST_INSTALL_DIR='$TMP/symlink-v2' DNSTEST_INSTALL_CMD='$TMP/no-command' DNSTEST_DASHBOARD_PATH='$TMP/no-dashboard' busybox ash '$ROOT/uninstall.sh'" /dev/null >/dev/null 2>&1; then
    echo 'Expected symlinked install directory to be rejected.' >&2
    exit 1
  fi
  test -f "$TMP/outside-v2/dns-bench.sh"
else
  echo 'TTY uninstall behavior skipped: util-linux script is unavailable.'
fi
grep -q 'preserved-v1-report' "$DNSTEST_V1_DIR/latest-top4.txt"
echo 'Installer rollback, v1 migration/restore, report preservation, upgrade backup and uninstall: PASS'
