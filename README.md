# Flint 2 DNS Benchmark 2

Independent v2 for GL.iNet Flint 2 / OpenWrt. Version 1 is not modified or overwritten.

## Install
Run on Flint 2 as root:
```sh
wget -O /tmp/dnstest2-install.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh && ash /tmp/dnstest2-install.sh
```
The installer installs only missing dependencies: `coreutils-timeout`, `knot-dig`, `curl`, `coreutils-base64`, `coreutils-od`, and `ca-bundle` (only when missing). It does not run `apk update`. The v2 command and files are separate: `dnstest2`, `/root/dnstest2/`. Version 1's `dnstest`, `/root/dnstest/`, reports and dashboard are untouched.

## Usage
- `dnstest2 --check`: local dependency checks only; no DNS queries.
- `dnstest2 --version`
- `dnstest2`: full benchmark.

## Method
- Public UDP/TCP: configured public IPv4 resolvers, including Level3 4.2.2.2/4.2.2.4, tested independently over UDP and TCP.
- Iranian DNS: all nine configured Iranian IPv4 endpoints, each tested over UDP and TCP; best two successful results are selected across both protocols.
- DoT: 13 configured TLS endpoints, with certificate and hostname validation.
- DoH: all 26 endpoints from the reference-site list, plus the pre-existing Mullvad entry; GET/POST wire-format requests, TLS verification, one warm-up round and two measured rounds across the reference site's 12 domains.
- Classic DNS tests use two rounds over github.com, nasa.gov and openwrt.org. Each failed sample is scored as 5000 ms, so a resolver with low success cannot rank unrealistically high.
- Tests are sequential to avoid creating artificial load on the router.

## Output
Exactly ten rows, in this order: two TCP, two UDP, two DoT, two DoH, two Iranian. Columns: `# DNS AVG IP TYPE OK`. Report: `/root/dnstest2/latest-top10.txt`.

## Dependencies
`kdig` from `knot-dig`; `curl` with HTTPS, `--resolve`, `--next`, `--write-out`; `ca-bundle`; `timeout`; BusyBox `awk grep sort sed base64 od tr wc`. No DNS, firewall, routes, or service settings are changed.

## Uninstall
```sh
wget -O /tmp/dnstest2-uninstall.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```
Only v2 scripts, command link and dashboard are removed after typing YES. Reports, backups, packages and v1 remain.
