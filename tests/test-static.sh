#!/bin/ash
set -eu
DNS_COUNT="$(sed -n "/^PUBLIC_SERVERS='/,/^'$/p" dns-bench.sh | grep -c '|')"
IRAN_COUNT="$(sed -n "/^IRAN_SERVERS='/,/^'$/p" dns-bench.sh | grep -c '|')"
DOT_COUNT="$(sed -n "/^DOT_SERVERS='/,/^'$/p" dns-bench.sh | grep -c '|')"
DOH_COUNT="$(sed -n "/^DEFAULT_DOH_SERVERS='/,/^'$/p" doh-bench.sh | grep -c '|')"
[ "$DNS_COUNT" -eq 27 ] || { echo "Expected 27 public DNS endpoints, got $DNS_COUNT"; exit 1; }
[ "$IRAN_COUNT" -eq 9 ] || { echo "Expected 9 Iranian DNS endpoints, got $IRAN_COUNT"; exit 1; }
[ "$DOT_COUNT" -eq 13 ] || { echo "Expected 13 DoT endpoints, got $DOT_COUNT"; exit 1; }
[ "$DOH_COUNT" -eq 26 ] || { echo "Expected 26 DoH endpoints, got $DOH_COUNT"; exit 1; }
grep -q "for GROUP in TCP UDP DOT DOH" dns-bench.sh
grep -q "mfranjbar/Flint-2-DNS-Benchmark-2" install.sh
grep -q "DIR='/root/dnstest2'" install.sh
grep -q "CMD='/usr/bin/dnstest2'" install.sh
! grep -q "/root/dnstest/" install.sh
grep -q 'DIR="${DNSTEST_DIR:-/root/dnstest2}"' doh-bench.sh
! grep -q 'DIR="${DNSTEST_DIR:-/root/dnstest}"' doh-bench.sh
echo "Static checks: 27 public, 9 Iranian, 13 DoT, 26 DoH; independent v2 paths: PASS"

grep -Fq 'TMP="/tmp/flint-dnstest2-$$"' dns-bench.sh
grep -Fq 'if (ok[1] + 0 > 0)' dns-bench.sh
grep -Fq 'Only $DOH_COUNT successful DoH resolvers' dns-bench.sh
