# Flint 2 DNS Benchmark v2 SSH dashboard
case "$-" in *i*) ;; *) return 0 2>/dev/null || exit 0 ;; esac
[ -n "${SSH_CONNECTION:-}" ] || return 0 2>/dev/null || exit 0
REPORT='/root/dnstest2/latest-top10.txt'
printf '\n  DNS BENCHMARK / FLINT 2 v2\n'
if [ -r "$REPORT" ]; then
  cat "$REPORT"
else
  printf '  No v2 benchmark report yet. Run dnstest2.\n'
fi
printf '\n'
