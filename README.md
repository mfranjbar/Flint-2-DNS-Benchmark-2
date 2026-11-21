# Flint 2 DNS Benchmark 2

A standalone DNS benchmarking tool for **GL.iNet Flint 2 and compatible OpenWrt systems**. It measures public IPv4 DNS resolvers over UDP, TCP, DNS-over-TLS (DoT), and DNS-over-HTTPS (DoH), plus a separate group of Iranian DNS servers.

This is an independent second version. It does **not** modify, replace, or depend on the original v1 project:
- v1 repository: https://github.com/mfranjbar/flint2-dns-benchmark-
- v2 repository: https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2

## Features

- Tests 27 public IPv4 DNS endpoints over UDP and TCP independently.
- Tests all 9 configured Iranian DNS endpoints over UDP and TCP.
- Tests 13 DNS-over-TLS endpoints with certificate and TLS-hostname verification.
- Tests 26 DNS-over-HTTPS providers using DNS wire-format requests and TLS verification.
- Includes Level3 DNS endpoints `4.2.2.2` and `4.2.2.4`.
- Runs sequentially to avoid creating unnecessary test load on the router.
- Uses one unscored warm-up round and two measured rounds.
- Applies a 5000 ms penalty to failed measured requests so unreliable resolvers do not rank artificially high.
- Keeps the final report to exactly 10 ranked rows.
- Does not configure or change DNS, DNSCrypt, Passwall2, firewall, routes, interfaces, or network services.
- Does not include local DNS or DNSCrypt in the results.

## Install

Run the following on the Flint 2 as **root**. The device needs `wget` (or `curl`) and internet access to download the installer.

### One-command installation

```sh
wget -O /tmp/dnstest2-install.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh && ash /tmp/dnstest2-install.sh
```

If wget is unavailable but curl is already installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh -o /tmp/dnstest2-install.sh && ash /tmp/dnstest2-install.sh
```

### Installer script

The complete installer is maintained in [install.sh](install.sh). It:
1. Checks that it is running as root.
2. Downloads the benchmark engine, DoH module, and SSH dashboard from this repository.
3. Checks script syntax and verifies the expected resolver counts.
4. Installs only missing runtime dependencies using `apk add` or `opkg install`; it does **not** run `apk update`.
5. Creates a timestamped backup of existing v2 files before replacing them during an upgrade.
6. Installs the command as `/usr/bin/dnstest2`, the project files under `/root/dnstest2/`, and the SSH login dashboard under `/etc/profile.d/`.
7. Runs the local `dnstest2 --check` pre-check before reporting success.

Runtime packages installed only when needed:
- `coreutils-timeout` — provides `timeout`
- `knot-dig` — provides `kdig`
- `curl` — HTTPS/DoH requests
- `coreutils-base64` — provides `base64`
- `coreutils-od` — provides `od`
- `ca-bundle` — installed only if a usable CA certificate bundle is missing

BusyBox utilities are used where available; separate packages are not installed for those utilities. The initial download requires at least one working downloader (`wget` or `curl`).

## Run

After installation, connect over SSH and run:

```sh
dnstest2
```

Other commands:

```sh
dnstest2 --check
dnstest2 --version
dnstest2 --help
```

- `--check` checks local dependencies and installation paths only; it sends no DNS queries.
- Running `dnstest2` starts the full benchmark.
- The SSH dashboard is installed at `/etc/profile.d/41-dnstest2-dashboard.sh`.

## Benchmark method

| Category | Test coverage |
|---|---|
| Public UDP | 27 public IPv4 resolvers |
| Public TCP | The same 27 resolvers, tested independently over TCP |
| Iranian DNS | 9 configured Iranian IPv4 endpoints over UDP and TCP |
| DoT | 13 TLS resolvers with CA and hostname validation |
| DoH | 26 providers using DNS wire-format HTTPS requests |

UDP, TCP, and DoT tests query `github.com`, `nasa.gov`, and `openwrt.org`. DoH tests use 12 configured hostnames: `google.com`, `youtube.com`, `facebook.com`, `instagram.com`, `chatgpt.com`, `x.com`, `whatsapp.com`, `reddit.com`, `wikipedia.org`, `amazon.com`, `tiktok.com`, and `pinterest.com`.

Each resolver receives one warm-up round that is excluded from the score, followed by two measured rounds. Failed measured samples are assigned a 5000 ms penalty. DoH responses are checked for HTTP success, matching DNS transaction ID, a valid DNS response, and acceptable DNS response codes. TLS certificate verification is enabled.

## Results

The final report contains exactly 10 rows, in this order:

1. Best TCP
2. Second-best TCP
3. Best UDP
4. Second-best UDP
5. Best DoT
6. Second-best DoT
7. Best DoH
8. Second-best DoH
9. Best Iranian DNS
10. Second-best Iranian DNS

Columns: `# DNS AVG IP TYPE OK`

The two Iranian entries are selected from the successful Iranian UDP and TCP results. The report is saved to:

```
/root/dnstest2/latest-top10.txt
```

The standalone DoH module also keeps its own detailed report at `/root/dnstest2/latest-doh.txt`.

## Uninstall

Run on the router as **root**:

```sh
wget -O /tmp/dnstest2-uninstall.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

If wget is unavailable but curl is installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh -o /tmp/dnstest2-uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

### Uninstaller script

The complete removal script is maintained in [uninstall.sh](uninstall.sh). It requires the user to type `YES` interactively, then removes only the v2 benchmark scripts, the `dnstest2` command link, and the v2 SSH dashboard.

It preserves:
- Benchmark reports and result files
- Installation backups
- Installed dependency packages
- DNS and network configuration
- The original v1 installation, command, dashboard, and reports

## Project files

- [install.sh](install.sh) — installer and dependency setup
- [uninstall.sh](uninstall.sh) — interactive v2 removal script
- [dns-bench.sh](dns-bench.sh) — UDP, TCP, DoT, Iranian DNS orchestration and final report
- [doh-bench.sh](doh-bench.sh) — standalone DoH testing engine
- [41-dnstest2-dashboard.sh](41-dnstest2-dashboard.sh) — SSH login dashboard
- [DOH.md](DOH.md) — DoH implementation notes

## Safety and scope

The benchmark performs DNS queries for measurement only. It does not change the router's active DNS configuration, DNSCrypt, Passwall2, firewall rules, routing tables, Wi-Fi, interfaces, or service settings. Version 2 uses separate paths and command names so it can coexist with version 1.
