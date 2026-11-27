<div align="center">

# Flint 2 DNS Benchmark

**A lightweight, sequential, multi-protocol DNS performance benchmark for GL.iNet Flint 2, Xiaomi AX3600, and compatible OpenWrt / ImmortalWrt routers.**

[![CI](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/actions/workflows/checks.yml/badge.svg?branch=main)](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/actions/workflows/checks.yml)
[![Version](https://img.shields.io/badge/version-2.0.0-blue)](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2)
[![Platform](https://img.shields.io/badge/platform-OpenWrt%20%7C%20ImmortalWrt-2496ED)](https://openwrt.org/)
[![Shell](https://img.shields.io/badge/shell-BusyBox%20ash-lightgrey)](https://busybox.net/)
[![License](https://img.shields.io/badge/license-see%20repository-lightgrey)](LICENSE)

[Overview](#overview) · [Features](#features) · [Install](#installation) · [Usage](#usage) · [Reports](#reports) · [Methodology](#benchmark-methodology) · [Migration](#v1-to-v2-migration) · [Uninstall](#uninstallation) · [Safety](#safety-and-privacy)

</div>

---

## Overview

Flint 2 DNS Benchmark compares DNS resolver response times across **UDP, TCP, DNS-over-TLS (DoT), and DNS-over-HTTPS (DoH)**. It also evaluates a dedicated list of Iranian DNS endpoints over UDP and TCP.

The benchmark is designed for router environments. Tests run sequentially, use BusyBox-compatible shell scripts, verify encrypted-transport certificates, and generate a fixed **10-row combined ranking**.

> [!IMPORTANT]
> **Version 2 is independent from version 1.** It uses separate installation paths, command names, reports, and an SSH login dashboard. The v1 repository is neither modified nor required. If a recognized v1 installation is found, the v2 installer can migrate its program files automatically while retaining v1 reports and data.

## Features

| Test category | Configured endpoints | Measurement |
|---|---:|---|
| Public DNS / UDP | 27 | DNS response time |
| Public DNS / TCP | 27 | DNS response time |
| Iranian DNS / UDP | 9 | DNS response time |
| Iranian DNS / TCP | 9 | DNS response time |
| DNS-over-TLS | 13 | TLS-verified DNS response time |
| DNS-over-HTTPS | 26 | HTTPS/TLS-verified DNS response time |

Additional capabilities:

- Sequential testing to avoid unnecessary concurrent benchmark traffic.
- One warm-up round followed by two measured rounds.
- Three query domains for UDP, TCP, and DoT; twelve configured domains for DoH.
- A 5000 ms penalty for failed measured requests.
- A fixed, category-ordered 10-row combined report.
- A separate detailed DoH report.
- SSH login dashboard displaying the latest combined report.
- Pre-install checks, dependency checks, timestamped backups, staged installation, and rollback.
- Ownership-aware v1 migration and v2 uninstallation.
- A non-invasive benchmark design: it does not rewrite DNS, firewall, routing, Wi-Fi, or service configuration.

## Installation

### Quick install

Connect to the router through SSH and run the following command as **root**:

```sh
wget -O /tmp/dnstest2-install.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh && ash /tmp/dnstest2-install.sh
```

If `wget` is unavailable and `curl` is installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh -o /tmp/dnstest2-install.sh && ash /tmp/dnstest2-install.sh
```

The installer downloads the current v2 scripts and dashboard, validates shell syntax and configured resolver counts, checks required utilities, creates backups, installs the files, and runs a local post-install check.

### Requirements

| Requirement | Details |
|---|---|
| Operating system | OpenWrt / ImmortalWrt with a BusyBox-compatible `ash` shell |
| Validated targets | GL.iNet Flint 2 and Xiaomi AX3600 |
| Other devices | May work when the required utilities and packages are available for the device architecture and configured package feeds |
| Access | SSH access with root privileges |
| Download utility | `wget` or `curl` |
| DNS utility | `kdig` from `knot-dig` |
| HTTPS utility | `curl` built with HTTPS/TLS support and the required command-line options |
| TLS trust | A usable CA certificate bundle |
| Other utilities | `timeout`, `base64`, `od`, and standard BusyBox/Linux utilities |

### Dependency handling

The installer reuses utilities already present on the router and attempts to install only missing requirements. Package selection is delegated to the router's configured feeds and architecture; package feeds are not hard-coded for a particular router.

- **APK-based systems:** the installer runs `apk update` only when it needs to install a missing dependency. It does not run `apk upgrade` and does not upgrade installed packages.
- **OPKG-based systems:** the installer uses the configured OPKG feeds to install missing dependencies; it does not automatically refresh package lists.
- **CA certificates:** a CA bundle is installed only if neither supported system CA bundle path is available.

Depending on what is already installed, the installer may need packages providing `timeout`, `kdig`, `curl`, `base64`, `od`, or CA certificates. Package names used by the installer include `coreutils-timeout`, `knot-dig`, `curl`, `coreutils-base64`, `coreutils-od`, and `ca-bundle`.

> [!NOTE]
> Installing missing dependencies can require package-manager access and a working internet connection. If a required package cannot be installed, the installer stops and reports the error. It does not proceed by silently skipping a required dependency.

## Usage

Run the complete benchmark:

```sh
dnstest2
```

### Command options

| Command | Action |
|---|---|
| `dnstest2` | Run the complete UDP, TCP, Iranian DNS, DoT, and DoH benchmark |
| `dnstest2 --check` | Check dependencies and local installation paths; sends no DNS queries |
| `dnstest2 --version` | Display the installed version |
| `dnstest2 --help` | Display command usage |

The pre-check is useful after installation or when troubleshooting missing dependencies:

```sh
dnstest2 --check
```

## Reports

The benchmark writes its results to the following locations:

| Path | Contents |
|---|---|
| `/root/dnstest2/latest-top10.txt` | Combined 10-row ranked report |
| `/root/dnstest2/latest-doh.txt` | Detailed DoH report, including minimum, median, average, maximum, success count, and resolver IPv4 |

The SSH login dashboard is installed at:

```
/etc/profile.d/41-dnstest2-dashboard.sh
```

It displays the latest combined report when an interactive SSH session starts. It does not run a new benchmark automatically.

### Combined report order

The combined report contains exactly ten rows, in this order:

| Rank | Category | Selection |
|---:|---|---|
| 1–2 | TCP | Two fastest successful public TCP resolvers |
| 3–4 | UDP | Two fastest successful public UDP resolvers |
| 5–6 | DoT | Two fastest successful DNS-over-TLS resolvers |
| 7–8 | DoH | Two fastest DoH providers with at least one verified successful measured response |
| 9–10 | Iranian DNS | Two fastest distinct Iranian resolver IPs across UDP/TCP |

The combined report columns are:

`#  DNS  AVG  IP  TYPE  OK`

The `OK` column shows successful measured queries against the total measured queries for that resolver. The report is written only after the benchmark has enough successful results to populate all required categories. If a category does not have at least two qualifying results, the run fails and the previous combined report is preserved.

## Benchmark methodology

### Query targets

UDP, TCP, and DoT tests query the following domains:

- `github.com`
- `nasa.gov`
- `openwrt.org`

DoH tests use twelve configured domains:

- `google.com`
- `youtube.com`
- `facebook.com`
- `instagram.com`
- `chatgpt.com`
- `x.com`
- `whatsapp.com`
- `reddit.com`
- `wikipedia.org`
- `amazon.com`
- `tiktok.com`
- `pinterest.com`

### Warm-up and measured rounds

For UDP, TCP, and DoT, each resolver receives one unscored warm-up query per test domain, followed by two measured rounds. With three domains, this means six measured queries per resolver and protocol.

For DoH, each provider receives one unscored warm-up query per configured domain, followed by two measured rounds. With twelve domains, this means twenty-four measured queries per provider.

Warm-up requests are excluded from the reported measurements.

### Timing, failures, and ranking

- Failed measured requests are assigned a **5000 ms** penalty in the average.
- A resolver with no successful measured response is not included as a successful result.
- Successful results are sorted by their measured average for category ranking.
- DoH responses must pass HTTP and DNS response checks before being counted as successful.
- The final report is validated for its required row count and category order before replacing the previous report.

The benchmark is intended for comparative latency testing under the current network conditions. Results can vary with the router, ISP, routing path, resolver load, endpoint availability, and time of day.

### DoH validation and transport

The DoH module sends DNS wire-format requests over HTTPS using the configured provider IP and TLS hostname. It uses the CA bundle for certificate verification and checks the HTTP status, DNS transaction ID, DNS response flag, and accepted DNS response codes. It supports the configured GET and POST request methods.

The DoH module also checks that the installed `curl` supports HTTPS/TLS, `--noproxy`, `--resolve`, `--next`, and timing output. These checks are important for direct endpoint testing and connection reuse.

## v1 to v2 migration

The v2 installer can automatically migrate a recognized installation of the original v1 benchmark. It recognizes the known Flint 2 v1 layout and the markerless AX3600 layout when the expected v1 script/report path and matching command symlink identify the installation.

**Do not manually remove v1 before running the v2 installer** if you want to use the automatic migration.

### Known v1 paths

| v1 component | Path |
|---|---|
| Benchmark script | `/root/dnstest/dns-bench.sh` |
| Command symlink | `/usr/bin/dnstest` |
| SSH dashboard | `/etc/profile.d/40-dnstest-dashboard.sh` |

### Migration safeguards

Before replacing recognized v1 program files, the installer:

1. Downloads the v2 files and validates their shell syntax and resolver counts.
2. Checks dependencies and required utilities.
3. Verifies known v1 paths and project-specific content instead of relying on filenames alone.
4. Creates a uniquely named, timestamped transaction backup.
5. Backs up recognized v1 scripts, dashboard, and command symlink.
6. Installs v2 into its separate paths.
7. Runs the v2 local pre-check.
8. Restores the backed-up files if a migration or installation step fails.

The migration retains v1 reports and data, including the `/root/dnstest/` directory and its existing report files. Installed dependency packages are also retained. If a file or symlink cannot be positively identified as belonging to v1, it is preserved and a warning is reported rather than being removed.

### v2 installation paths

| Component | Path |
|---|---|
| Main benchmark | `/root/dnstest2/dns-bench.sh` |
| DoH module | `/root/dnstest2/doh-bench.sh` |
| Command | `/usr/bin/dnstest2` |
| SSH dashboard | `/etc/profile.d/41-dnstest2-dashboard.sh` |
| Backup root | `/root/backup/dns-benchmark-2/` |

## Uninstallation

To uninstall v2, connect over SSH and run the following command as **root**:

```sh
wget -O /tmp/dnstest2-uninstall.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

If `wget` is unavailable and `curl` is installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh -o /tmp/dnstest2-uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

The uninstaller requires interactive confirmation. At the prompt, type:

```
YES
```

### What the uninstaller removes

Only recognized v2 program files are removed:

- The v2 benchmark script.
- The v2 DoH script.
- The v2 command symlink, only if it points to the expected v2 script.
- The v2 SSH dashboard, only if its v2 identity marker is present.

### What is preserved

The uninstaller deliberately preserves:

- Benchmark reports and result files.
- Timestamped installation and migration backups.
- Installed dependency packages.
- The original v1 scripts, command, dashboard, reports, and data directory.
- DNS and DNSCrypt settings.
- Passwall2 and proxy configuration.
- Firewall rules, routing tables, interfaces, Wi-Fi, and router services.
- Unrecognized files, unrelated command links, and unrelated dashboard files.

The uninstaller does not remove packages or automatically delete directories containing user data.

## Safety and privacy

The benchmark sends DNS queries to the configured resolver endpoints. It does not need to become the router's active DNS service.

The benchmark scripts do **not** change:

- The router's active DNS or DNSCrypt configuration.
- Passwall2, proxy, or VPN settings.
- Firewall rules or routing tables.
- Network interfaces or Wi-Fi configuration.
- Router services or listening ports.

The installer may install missing software dependencies and, on APK-based systems, refresh package indexes when required. It does not upgrade installed packages. Installation and migration use backups and rollback safeguards; uninstallation preserves reports, backups, packages, and v1 data.

> [!WARNING]
> This is a latency and basic response-validation tool. It is **not** a comprehensive DNS security, privacy, malware-filtering, DNSSEC, or leak-test audit. A low response time does not by itself mean a resolver is the best choice for every use case.

## Troubleshooting

### The installer reports a missing dependency

Run the installer again after checking that the router has working internet access and valid package feeds for its architecture. On APK-based systems, the installer refreshes indexes only when it needs to install a missing dependency.

### The pre-check fails

Run:

```sh
dnstest2 --check
```

Check the reported missing utility, CA bundle, or DoH prerequisite. The pre-check does not send DNS queries.

### The benchmark cannot complete the 10-row report

The combined report requires at least two qualifying results in each category. Resolver outages, blocked protocols, network filtering, or TLS validation failures can prevent a category from meeting that requirement. The previous combined report is preserved if the new run fails validation.

### Results differ between runs

DNS latency is time- and route-dependent. Repeat the benchmark under comparable network conditions and avoid treating a single run as a permanent ranking.

## Project structure

| File | Purpose |
|---|---|
| [`install.sh`](install.sh) | Dependency checks, v1 migration, backups, transactional installation, and rollback |
| [`uninstall.sh`](uninstall.sh) | Interactive and ownership-aware v2 removal |
| [`dns-bench.sh`](dns-bench.sh) | UDP, TCP, DoT, Iranian DNS tests, and combined report generation |
| [`doh-bench.sh`](doh-bench.sh) | DNS-over-HTTPS measurement and validation |
| [`41-dnstest2-dashboard.sh`](41-dnstest2-dashboard.sh) | SSH login dashboard |
| [`DOH.md`](DOH.md) | DoH implementation notes |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |
| [`tests/`](tests/) | Static, orchestrator, and installer lifecycle tests |
| [`.github/workflows/checks.yml`](.github/workflows/checks.yml) | Automated CI checks |

## Continuous integration

The repository's GitHub Actions workflow checks shell syntax and runs automated static and mocked integration/lifecycle tests. These tests help validate script structure, report orchestration, and installer/uninstaller behavior in an isolated test environment.

> [!NOTE]
> Passing CI tests does not constitute a live DNS performance test from your router or prove that every external resolver is reachable from every ISP or country. Actual latency and endpoint availability must be measured on the target network.

## Project links

<div align="center">

**Flint 2 DNS Benchmark · v2.0.0**

[Repository](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2) · [Issues](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/issues) · [Changelog](CHANGELOG.md) · [CI status](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/actions)

</div>
