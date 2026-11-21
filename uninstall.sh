#!/bin/ash
set -u
[ "$(id -u)" = 0 ] || { echo 'Run as root.'; exit 1; }
DIR="${DNSTEST_INSTALL_DIR:-/root/dnstest2}"; CMD="${DNSTEST_INSTALL_CMD:-/usr/bin/dnstest2}"; DASH="${DNSTEST_DASHBOARD_PATH:-/etc/profile.d/41-dnstest2-dashboard.sh}"
echo 'This removes only DNS Benchmark v2 scripts, command link and dashboard.'
echo 'Reports, backups, packages, DNS settings and version 1 are preserved.'
[ -r /dev/tty ] && [ -w /dev/tty ] || { echo 'Interactive confirmation required.'; exit 1; }
printf 'Type YES to uninstall v2: ' >/dev/tty
IFS= read -r A </dev/tty || exit 1
[ "$A" = YES ] || { echo 'Cancelled.'; exit 1; }
[ ! -f "$DIR/dns-bench.sh" ] || grep -Fq 'FLINT 2 DNS BENCHMARK v2' "$DIR/dns-bench.sh" && rm -f "$DIR/dns-bench.sh"
[ ! -f "$DIR/doh-bench.sh" ] || grep -Fq 'FLINT 2 DNS OVER HTTPS BENCHMARK' "$DIR/doh-bench.sh" && rm -f "$DIR/doh-bench.sh"
[ ! -L "$CMD" ] || { [ "$(readlink "$CMD")" = "$DIR/dns-bench.sh" ] && rm -f "$CMD"; }
[ ! -f "$DASH" ] || grep -Fq 'DNS Benchmark v2 SSH dashboard' "$DASH" && rm -f "$DASH"
echo 'v2 scripts removed; reports, backups, packages and v1 preserved.'
