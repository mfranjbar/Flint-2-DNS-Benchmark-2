#!/bin/ash
# Remove only files positively identified as this project's v2 installation.
set -u
[ "$(id -u)" = 0 ] || { echo 'Run as root.'; exit 1; }

DIR="${DNSTEST_INSTALL_DIR:-/root/dnstest2}"
CMD="${DNSTEST_INSTALL_CMD:-/usr/bin/dnstest2}"
DASH="${DNSTEST_DASHBOARD_PATH:-/etc/profile.d/41-dnstest2-dashboard.sh}"

# Never traverse a user-supplied or unexpected symlink as the installation directory.
[ ! -L "$DIR" ] || { echo "Refusing to uninstall through symlinked install directory: $DIR"; exit 1; }

echo 'This removes only recognized DNS Benchmark v2 scripts, command link and dashboard.'
echo 'Reports, backups, packages, DNS settings, network settings and version 1 are preserved.'
[ -r /dev/tty ] && [ -w /dev/tty ] || { echo 'Interactive confirmation required.'; exit 1; }
printf 'Type YES to uninstall v2: ' >/dev/tty
IFS= read -r ANSWER </dev/tty || exit 1
[ "$ANSWER" = YES ] || { echo 'Cancelled.'; exit 1; }

REMOVED=0
SKIPPED=0

if [ -f "$DIR/dns-bench.sh" ] && [ ! -L "$DIR/dns-bench.sh" ]; then
  if grep -Fq 'FLINT 2 DNS BENCHMARK v2' "$DIR/dns-bench.sh"; then
    rm -f "$DIR/dns-bench.sh" || { echo 'Could not remove main v2 script.'; exit 1; }
    REMOVED=$((REMOVED+1))
  else
    echo "Preserved unrecognized file: $DIR/dns-bench.sh"
    SKIPPED=$((SKIPPED+1))
  fi
fi

if [ -f "$DIR/doh-bench.sh" ] && [ ! -L "$DIR/doh-bench.sh" ]; then
  if grep -Fq 'FLINT 2 DNS OVER HTTPS BENCHMARK' "$DIR/doh-bench.sh"; then
    rm -f "$DIR/doh-bench.sh" || { echo 'Could not remove DoH v2 script.'; exit 1; }
    REMOVED=$((REMOVED+1))
  else
    echo "Preserved unrecognized file: $DIR/doh-bench.sh"
    SKIPPED=$((SKIPPED+1))
  fi
fi

if [ -L "$CMD" ]; then
  TARGET="$(readlink "$CMD")"
  if [ "$TARGET" = "$DIR/dns-bench.sh" ]; then
    rm -f "$CMD" || { echo 'Could not remove v2 command link.'; exit 1; }
    REMOVED=$((REMOVED+1))
  else
    echo "Preserved unrelated command symlink: $CMD -> $TARGET"
    SKIPPED=$((SKIPPED+1))
  fi
elif [ -e "$CMD" ]; then
  echo "Preserved non-symlink command path: $CMD"
  SKIPPED=$((SKIPPED+1))
fi

if [ -f "$DASH" ] && [ ! -L "$DASH" ]; then
  if grep -Fq 'Flint 2 DNS Benchmark v2 SSH dashboard' "$DASH"; then
    rm -f "$DASH" || { echo 'Could not remove v2 dashboard.'; exit 1; }
    REMOVED=$((REMOVED+1))
  else
    echo "Preserved unrelated dashboard: $DASH"
    SKIPPED=$((SKIPPED+1))
  fi
elif [ -L "$DASH" ]; then
  echo "Preserved dashboard symlink: $DASH"
  SKIPPED=$((SKIPPED+1))
fi

echo "Uninstall finished. Removed: $REMOVED; preserved unrelated paths: $SKIPPED."
echo 'Reports, backups, installed packages, DNS/network settings and version 1 were preserved.'
