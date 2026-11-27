#!/bin/ash
# Transactional installer for DNS Benchmark v2. Never overwrites v1 or unrelated files.
set -u

REPO='mfranjbar/Flint-2-DNS-Benchmark-2'
BRANCH='main'
BASE="${DNSTEST_BASE_URL:-https://raw.githubusercontent.com/$REPO/$BRANCH}"
DIR="${DNSTEST_INSTALL_DIR:-/root/dnstest2}"
CMD="${DNSTEST_INSTALL_CMD:-/usr/bin/dnstest2}"
DASH="${DNSTEST_DASHBOARD_PATH:-/etc/profile.d/41-dnstest2-dashboard.sh}"
BACKUP_ROOT="${DNSTEST_BACKUP_ROOT:-/root/backup/dns-benchmark-2}"
WORK="$(mktemp -d /tmp/dnstest2-install.XXXXXX)" || exit 1
TRANSACTION=0
HAD_DNS=0
HAD_DOH=0
HAD_DASH=0
HAD_CMD=0
say(){ printf '%s\n' "$*"; }
die(){ say "ERROR: $*" >&2; if [ "$TRANSACTION" -eq 1 ]; then rollback; fi; exit 1; }

[ "$(id -u)" = 0 ] || die 'Run as root.'
cleanup(){
  rm -f "$DIR/.dns-bench.sh.new" "$DIR/.doh-bench.sh.new" "$DASH.new" "$CMD.new"
  rm -rf "$WORK"
}
trap cleanup EXIT

fetch(){
  if command -v wget >/dev/null 2>&1 && wget -q -O "$2" "$1" && [ -s "$2" ]; then return 0; fi
  if command -v curl >/dev/null 2>&1 && curl -fsSL "$1" -o "$2" && [ -s "$2" ]; then return 0; fi
  return 1
}
install_pkg(){
  P="$1"; C="$2"
  command -v "$C" >/dev/null 2>&1 && return 0
  say "Installing missing dependency: $P"
  if command -v apk >/dev/null 2>&1; then apk add "$P" || die "Could not install $P (no apk update is run)."
  elif command -v opkg >/dev/null 2>&1; then opkg install "$P" || die "Could not install $P."
  else die 'Neither apk nor opkg is available.'; fi
  command -v "$C" >/dev/null 2>&1 || die "$P installed but $C is unavailable."
}
restore_file(){
  SOURCE="$1"; TARGET="$2"; HAD="$3"; LINK="$4"
  rm -f "$TARGET"
  if [ "$HAD" -eq 1 ]; then
    if [ "$LINK" -eq 1 ]; then cp -P "$SOURCE" "$TARGET"
    else cp -p "$SOURCE" "$TARGET"; fi
  fi
}
rollback(){
  say 'Installation failed; restoring the previous v2 state.'
  restore_file "$BACKUP/dns-bench.sh" "$DIR/dns-bench.sh" "$HAD_DNS" 0 || say 'WARNING: main script restore failed.'
  restore_file "$BACKUP/doh-bench.sh" "$DIR/doh-bench.sh" "$HAD_DOH" 0 || say 'WARNING: DoH script restore failed.'
  restore_file "$BACKUP/41-dnstest2-dashboard.sh" "$DASH" "$HAD_DASH" 0 || say 'WARNING: dashboard restore failed.'
  restore_file "$BACKUP/dnstest2-command-link" "$CMD" "$HAD_CMD" 1 || say 'WARNING: command link restore failed.'
  TRANSACTION=0
}

say 'FLINT 2 DNS BENCHMARK v2 INSTALLER'
mkdir -p "$WORK" || die 'Cannot create work directory.'
fetch "$BASE/dns-bench.sh" "$WORK/dns-bench.sh" || die 'Cannot download main benchmark.'
fetch "$BASE/doh-bench.sh" "$WORK/doh-bench.sh" || die 'Cannot download DoH module.'
fetch "$BASE/41-dnstest2-dashboard.sh" "$WORK/dashboard.sh" || die 'Cannot download dashboard.'
for F in dns-bench.sh doh-bench.sh dashboard.sh; do
  ash -n "$WORK/$F" || die "Syntax error in $F"
done

DNS_COUNT="$(sed -n "/^PUBLIC_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
IRAN_COUNT="$(sed -n "/^IRAN_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
DOT_COUNT="$(sed -n "/^DOT_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
DOH_COUNT="$(sed -n "/^DEFAULT_DOH_SERVERS='/,/^'$/p" "$WORK/doh-bench.sh" | grep -c '|')"
[ "$DNS_COUNT" -eq 27 ] || die "Public DNS list mismatch: $DNS_COUNT (expected 27)."
[ "$IRAN_COUNT" -eq 9 ] || die "Iranian DNS list mismatch: $IRAN_COUNT (expected 9)."
[ "$DOT_COUNT" -eq 13 ] || die "DoT list mismatch: $DOT_COUNT (expected 13)."
[ "$DOH_COUNT" -eq 26 ] || die "DoH list mismatch: $DOH_COUNT (expected 26)."

# Refuse to replace paths that do not belong to this v2 installation.
[ ! -e "$DIR" ] || [ -d "$DIR" ] || die "Install path exists and is not a directory: $DIR"
[ ! -e "$CMD" ] || [ -L "$CMD" ] || die "Refusing to overwrite a regular file at $CMD"
if [ -L "$CMD" ]; then
  CMD_TARGET="$(readlink "$CMD")"
  [ "$CMD_TARGET" = "$DIR/dns-bench.sh" ] || die "Refusing to replace unrelated command symlink: $CMD -> $CMD_TARGET"
fi
if [ -e "$DIR/dns-bench.sh" ]; then
  grep -Fq 'FLINT 2 DNS BENCHMARK v2' "$DIR/dns-bench.sh" || die 'Existing main script is not recognized as v2; refusing to overwrite.'
fi
if [ -e "$DIR/doh-bench.sh" ]; then
  grep -Fq 'FLINT 2 DNS OVER HTTPS BENCHMARK' "$DIR/doh-bench.sh" || die 'Existing DoH script is not recognized as v2; refusing to overwrite.'
fi
if [ -e "$DASH" ]; then
  grep -Fq 'Flint 2 DNS Benchmark v2 SSH dashboard' "$DASH" || die 'Existing SSH dashboard is unrelated; refusing to overwrite.'
fi

# Install only missing runtime dependencies. No package index refresh is performed.
install_pkg coreutils-timeout timeout
install_pkg knot-dig kdig
install_pkg curl curl
install_pkg coreutils-base64 base64
install_pkg coreutils-od od
if [ ! -s /etc/ssl/cert.pem ] && [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
  say 'Installing CA certificate bundle: ca-bundle'
  if command -v apk >/dev/null 2>&1; then apk add ca-bundle || die 'Could not install ca-bundle.'
  elif command -v opkg >/dev/null 2>&1; then opkg install ca-bundle || die 'Could not install ca-bundle.'
  else die 'Neither apk nor opkg is available for ca-bundle.'; fi
fi
[ -s /etc/ssl/cert.pem ] || [ -s /etc/ssl/certs/ca-certificates.crt ] || die 'CA bundle is still missing.'
for C in awk grep sort head sed date mkdir rmdir rm mv cat base64 od tr wc cp readlink ln chmod; do
  command -v "$C" >/dev/null 2>&1 || die "Missing required utility: $C"
done

mkdir -p "$DIR" "$BACKUP_ROOT" /etc/profile.d || die 'Cannot create install directories.'
STAMP="$(date '+%Y%m%d-%H%M%S')-$$"
BACKUP="$BACKUP_ROOT/$STAMP"
mkdir -p "$BACKUP" || die 'Cannot create transaction backup directory.'

[ ! -e "$DIR/dns-bench.sh" ] || { cp -p "$DIR/dns-bench.sh" "$BACKUP/dns-bench.sh" && HAD_DNS=1; } || die 'Main script backup failed.'
[ ! -e "$DIR/doh-bench.sh" ] || { cp -p "$DIR/doh-bench.sh" "$BACKUP/doh-bench.sh" && HAD_DOH=1; } || die 'DoH script backup failed.'
[ ! -e "$DASH" ] || { cp -p "$DASH" "$BACKUP/41-dnstest2-dashboard.sh" && HAD_DASH=1; } || die 'Dashboard backup failed.'
[ ! -L "$CMD" ] || { cp -P "$CMD" "$BACKUP/dnstest2-command-link" && HAD_CMD=1; } || die 'Command link backup failed.'

cp "$WORK/dns-bench.sh" "$DIR/.dns-bench.sh.new" || die 'Could not stage main script.'
cp "$WORK/doh-bench.sh" "$DIR/.doh-bench.sh.new" || die 'Could not stage DoH script.'
cp "$WORK/dashboard.sh" "$DASH.new" || die 'Could not stage dashboard.'
ln -s "$DIR/dns-bench.sh" "$CMD.new" || die 'Could not stage command link.'
chmod 755 "$DIR/.dns-bench.sh.new" "$DIR/.doh-bench.sh.new" || die 'Could not set script permissions.'
chmod 644 "$DASH.new" || die 'Could not set dashboard permissions.'

TRANSACTION=1
mv -f "$DIR/.dns-bench.sh.new" "$DIR/dns-bench.sh" || die 'Could not install main script.'
mv -f "$DIR/.doh-bench.sh.new" "$DIR/doh-bench.sh" || die 'Could not install DoH script.'
mv -f "$DASH.new" "$DASH" || die 'Could not install dashboard.'
mv -f "$CMD.new" "$CMD" || die 'Could not install command link.'

SHELL_BIN="${DNSTEST_INSTALL_SHELL:-ash}"
DNSTEST_DIR="$DIR" DNSTEST_KDIG="${DNSTEST_KDIG:-/usr/bin/kdig}" "$SHELL_BIN" "$CMD" --check || die 'Installed pre-check failed; previous files have been restored.'
TRANSACTION=0

say 'Installation complete. Run: dnstest2'
say 'Version 1 paths and command were not touched.'
say 'No DNS, firewall, routing or service settings were changed.'
say "Backup directory: $BACKUP"
exit 0
