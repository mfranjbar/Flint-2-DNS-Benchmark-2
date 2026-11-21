#!/bin/ash
# Independent installer for DNS Benchmark v2. Never overwrites v1 paths.
set -u
REPO='mfranjbar/Flint-2-DNS-Benchmark-2'
BRANCH='main'
BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"
DIR='/root/dnstest2'
CMD='/usr/bin/dnstest2'
DASH='/etc/profile.d/41-dnstest2-dashboard.sh'
BACKUP_ROOT='/root/backup/dns-benchmark-2'
WORK="$(mktemp -d /tmp/dnstest2-install.XXXXXX)" || exit 1
say(){ printf '%s\n' "$*"; }
die(){ say "ERROR: $*"; exit 1; }
[ "$(id -u)" = 0 ] || die 'Run as root.'
cleanup(){
  rm -f "$DIR/.dns-bench.sh.new" "$DIR/.doh-bench.sh.new" "$DASH.new"
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
say 'FLINT 2 DNS BENCHMARK v2 INSTALLER'
mkdir -p "$WORK" || die 'Cannot create work directory.'
fetch "$BASE/dns-bench.sh" "$WORK/dns-bench.sh" || die 'Cannot download main benchmark.'
fetch "$BASE/doh-bench.sh" "$WORK/doh-bench.sh" || die 'Cannot download DoH module.'
fetch "$BASE/41-dnstest2-dashboard.sh" "$WORK/dashboard.sh" || die 'Cannot download dashboard.'
for F in dns-bench.sh doh-bench.sh dashboard.sh; do ash -n "$WORK/$F" || die "Syntax error in $F"; done
DNS_COUNT="$(sed -n "/^PUBLIC_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
IRAN_COUNT="$(sed -n "/^IRAN_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
DOT_COUNT="$(sed -n "/^DOT_SERVERS='/,/^'$/p" "$WORK/dns-bench.sh" | grep -c '|')"
DOH_COUNT="$(sed -n "/^DEFAULT_DOH_SERVERS='/,/^'$/p" "$WORK/doh-bench.sh" | grep -c '|')"
[ "$DNS_COUNT" -eq 27 ] || die "Public DNS list mismatch: $DNS_COUNT (expected 27)."
[ "$IRAN_COUNT" -eq 9 ] || die "Iranian DNS list mismatch: $IRAN_COUNT (expected 9)."
[ "$DOT_COUNT" -eq 13 ] || die "DoT list mismatch: $DOT_COUNT (expected 13)."
[ "$DOH_COUNT" -eq 26 ] || die "DoH list mismatch: $DOH_COUNT (expected 26)."
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
# nl is not required by v2; base64, od and text tools are checked below.
for C in awk grep sort head sed date mkdir rmdir rm mv cat base64 od tr wc; do command -v "$C" >/dev/null 2>&1 || die "Missing required utility: $C"; done
mkdir -p "$DIR" "$BACKUP_ROOT" /etc/profile.d || die 'Cannot create install directories.'
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_ROOT/$STAMP"
if [ -e "$DIR/dns-bench.sh" ] || [ -e "$DIR/doh-bench.sh" ] || [ -e "$DASH" ] || [ -L "$CMD" ]; then
  mkdir -p "$BACKUP" || die 'Cannot create backup.'
  [ ! -e "$DIR/dns-bench.sh" ] || cp -p "$DIR/dns-bench.sh" "$BACKUP/" || die 'Backup failed.'
  [ ! -e "$DIR/doh-bench.sh" ] || cp -p "$DIR/doh-bench.sh" "$BACKUP/" || die 'Backup failed.'
  [ ! -e "$DASH" ] || cp -p "$DASH" "$BACKUP/" || die 'Backup failed.'
  [ ! -L "$CMD" ] || cp -P "$CMD" "$BACKUP/dnstest2-link" || die 'Backup failed.'
fi
cp "$WORK/dns-bench.sh" "$DIR/.dns-bench.sh.new" || die 'Stage failed.'
cp "$WORK/doh-bench.sh" "$DIR/.doh-bench.sh.new" || die 'Stage failed.'
cp "$WORK/dashboard.sh" "$DASH.new" || die 'Stage failed.'
chmod 755 "$DIR/.dns-bench.sh.new" "$DIR/.doh-bench.sh.new" || die 'chmod failed.'
chmod 644 "$DASH.new" || die 'chmod failed.'
mv -f "$DIR/.dns-bench.sh.new" "$DIR/dns-bench.sh" || die 'Install main failed.'
mv -f "$DIR/.doh-bench.sh.new" "$DIR/doh-bench.sh" || die 'Install DoH failed.'
mv -f "$DASH.new" "$DASH" || die 'Install dashboard failed.'
ln -sf "$DIR/dns-bench.sh" "$CMD" || die 'Command link failed.'
DNSTEST_DIR="$DIR" "$CMD" --check || die 'Installed pre-check failed.'
say 'Installation complete. Run: dnstest2'
say 'Version 1 paths and command were not touched.'
say 'No DNS, firewall, routing or service settings were changed.'
[ -d "$BACKUP" ] && say "Backup: $BACKUP"
