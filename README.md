<div align="center">

# Flint 2 DNS Benchmark

**A lightweight, multi-protocol DNS benchmark for GL.iNet Flint 2 and compatible OpenWrt routers.**

[![CI](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/actions/workflows/checks.yml/badge.svg?branch=main)](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/actions/workflows/checks.yml)
[![Version](https://img.shields.io/badge/version-2.0.0-blue)](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2)
[![Platform](https://img.shields.io/badge/platform-OpenWrt%20%7C%20ImmortalWrt-2496ED)](https://openwrt.org/)
[![Shell](https://img.shields.io/badge/shell-BusyBox%20ash-lightgrey)](https://busybox.net/)

[Features](#-features) · [Quick install](#-quick-install) · [Run](#-run-the-benchmark) · [Uninstall](#-uninstall) · [Methodology](#-benchmark-methodology) · [Safety](#-safety--v1-to-v2-migration)

</div>

---

## Overview

Flint 2 DNS Benchmark measures resolver response times across **UDP, TCP, DNS-over-TLS (DoT), and DNS-over-HTTPS (DoH)**. It also tests a separate set of Iranian DNS endpoints and produces a compact, ranked report directly on your router.

The project is designed for router environments: tests run sequentially, use BusyBox-compatible shell scripts, and avoid changing the router's active network configuration.

> **Version 2 is a separate project.** It uses its own command, installation directory, dashboard, and reports. The original v1 repository is not modified or required.

| Project | Repository |
|---|---|
| Original version 1 | [mfranjbar/flint2-dns-benchmark-](https://github.com/mfranjbar/flint2-dns-benchmark-) |
| Current version 2 | [mfranjbar/Flint-2-DNS-Benchmark-2](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2) |

## ✨ Features

- **27 public DNS endpoints** tested independently over UDP and TCP.
- **9 Iranian DNS endpoints** tested over UDP and TCP.
- **13 DNS-over-TLS resolvers**, with certificate and TLS hostname verification.
- **26 DNS-over-HTTPS providers**, using DNS wire-format HTTPS requests and TLS verification.
- Includes Level3 endpoints `4.2.2.2` and `4.2.2.4`.
- Sequential measurements to avoid unnecessary concurrent load on the router.
- One warm-up round (not scored) followed by two measured rounds.
- Failed measured requests receive a 5000 ms penalty so unreliable servers do not rank artificially high.
- A consistent **10-row final report**, separated by protocol/category.
- An SSH login dashboard showing the latest benchmark report.
- Installer with preflight checks, backups, staged file replacement, and rollback.
- Automatic migration of a recognized v1 installation to v2.

## ⚡ Quick install

Connect to your router over SSH and run the following command as **root**.

### Install / upgrade

```sh
wget -O /tmp/dnstest2-install.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh && ash /tmp/dnstest2-install.sh
```

If `wget` is unavailable and `curl` is installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/install.sh -o /tmp/dnstest2-install.sh && ash /tmp/dnstest2-install.sh
```

The installer downloads the benchmark scripts and dashboard, checks their syntax and resolver counts, installs only missing dependencies, and runs a local post-install check. It does **not** run `apk update`.

### Requirements

| Requirement | Details |
|---|---|
| Router | OpenWrt / ImmortalWrt with BusyBox `ash`; ImmortalWrt 25.12.x (`apk`) is supported. AX3600 and Flint 2 are validated targets. Other models depend on package availability for their configured target and architecture. |
| Access | SSH shell with root privileges |
| Shell | BusyBox `ash` |
| Download | `wget` or `curl` and internet access |
| Package manager | `apk` or `opkg`, only if a dependency is missing |

The installer checks for these runtime tools and installs only what is missing. On `apk` systems, it refreshes package indexes automatically and only when a required utility is missing; it does not upgrade installed packages. Package selection is delegated to the router's configured APK feeds and architecture (`/etc/apk/arch`), so the installer does not hard-code an AX3600 or Flint 2 feed:

| Package | Utility / purpose |
|---|---|
| `coreutils-timeout` | `timeout` |
| `knot-dig` | `kdig` |
| `curl` | HTTPS and DoH requests |
| `coreutils-base64` | `base64` |
| `coreutils-od` | `od` |
| `ca-bundle` | CA certificates, only when no usable bundle exists |

BusyBox-provided utilities are reused where available. On `opkg` systems, the installer does not refresh package lists automatically; configure package feeds and indexes before installing if a dependency is missing.

## ▶️ Run the benchmark

After installation, run:

```sh
dnstest2
```

Useful commands:

| Command | Description |
|---|---|
| `dnstest2` | Run the complete DNS benchmark |
| `dnstest2 --check` | Check local dependencies and installation paths; sends no DNS queries |
| `dnstest2 --version` | Display the installed version |
| `dnstest2 --help` | Display command help |

### Output files

| File | Description |
|---|---|
| `/root/dnstest2/latest-top10.txt` | Combined 10-row ranked report |
| `/root/dnstest2/latest-doh.txt` | Detailed DoH report |

The SSH dashboard is installed at:

```
/etc/profile.d/41-dnstest2-dashboard.sh
```

## 🧹 Uninstall

To remove version 2, connect over SSH and run this command as **root**:

```sh
wget -O /tmp/dnstest2-uninstall.sh https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

If `wget` is unavailable and `curl` is installed:

```sh
curl -fsSL https://raw.githubusercontent.com/mfranjbar/Flint-2-DNS-Benchmark-2/main/uninstall.sh -o /tmp/dnstest2-uninstall.sh && ash /tmp/dnstest2-uninstall.sh
```

**Uninstallation requires interactive confirmation.** When prompted, type:

```
YES
```

The uninstaller removes only recognized v2 benchmark scripts, the v2 command symlink, and the v2 SSH dashboard. It deliberately preserves:

- Benchmark reports and result files.
- Timestamped installation and migration backups.
- Installed dependency packages.
- The original v1 files, command, dashboard, reports, and data directory.
- DNS, DNSCrypt, Passwall2, firewall, routing, interface, Wi-Fi, and service configuration.
- Unrecognized files and unrelated command links.

The uninstaller does not remove packages and does not attempt to clean up directories containing user data.

## 🔄 Automatic v1 → v2 migration

If the original v1 installation is present, the v2 installer can migrate it automatically. It recognizes both the marked Flint 2 v1 layout and the markerless AX3600 layout when the known v1 script, report path, and matching `/usr/bin/dnstest` symlink identify the installation. **Do not manually delete v1 first.**

The installer checks the known v1 locations and verifies project-specific content before treating a file as belonging to v1:

| v1 artifact | Known location |
|---|---|
| Benchmark script | `/root/dnstest/dns-bench.sh` |
| Command link | `/usr/bin/dnstest` |
| SSH dashboard | `/etc/profile.d/40-dnstest-dashboard.sh` |

When recognized, the installer:

1. Creates a private, uniquely named transaction backup.
2. Backs up the v1 benchmark script, dashboard, and command link.
3. Removes only those positively identified v1 program files.
4. Installs v2 under its separate paths: `/root/dnstest2/`, `/usr/bin/dnstest2`, and `/etc/profile.d/41-dnstest2-dashboard.sh`.
5. Runs the v2 local pre-check.
6. Restores the previous files if migration, installation, or the pre-check fails.

**Your v1 reports and data are retained**, including `/root/dnstest/latest-top4.txt`, the `/root/dnstest/` directory, previous backups, and installed packages. If a file or symlink cannot be positively identified, it is left untouched and the installer reports a warning instead of guessing.

## 📊 Benchmark methodology

| Test group | Coverage |
|---|---:|
| Public DNS over UDP | 27 endpoints |
| Public DNS over TCP | Same 27 endpoints, tested independently |
| Iranian DNS over UDP/TCP | 9 configured endpoints |
| DNS-over-TLS | 13 endpoints |
| DNS-over-HTTPS | 26 providers |

UDP, TCP, and DoT tests query `github.com`, `nasa.gov`, and `openwrt.org`.

DoH tests use 12 configured hostnames: `google.com`, `youtube.com`, `facebook.com`, `instagram.com`, `chatgpt.com`, `x.com`, `whatsapp.com`, `reddit.com`, `wikipedia.org`, `amazon.com`, `tiktok.com`, and `pinterest.com`.

Each resolver receives one unscored warm-up round and two measured rounds. Failed measured samples receive a 5000 ms penalty. DoH responses are checked for HTTP success, matching DNS transaction ID, a valid DNS response, and acceptable DNS response codes. TLS certificate verification is enabled.

### Final report layout

The combined report contains exactly 10 ranked rows:

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

Columns: `# DNS AVG IP TYPE OK`.

The two Iranian entries are selected from successful Iranian UDP and TCP results. The ranking reflects the test conditions and network path at the time of measurement; it is not a guarantee of future performance.

## 🛡️ Safety and scope

The benchmark sends DNS queries for measurement. It does **not** configure or change:

- Active DNS settings or DNSCrypt.
- Passwall2 or proxy configuration.
- Firewall rules or routing tables.
- Network interfaces, Wi-Fi, or router services.

The installer and uninstaller do not change these settings either. The installer does not run `apk update` and does not remove packages. Backups are retained for manual recovery; they are not automatically deleted.

## 📁 Project structure

| File | Purpose |
|---|---|
| [`install.sh`](install.sh) | Installer, dependency checks, v1 migration, rollback |
| [`uninstall.sh`](uninstall.sh) | Interactive, ownership-aware v2 removal |
| [`dns-bench.sh`](dns-bench.sh) | UDP, TCP, DoT, Iranian DNS orchestration and final report |
| [`doh-bench.sh`](doh-bench.sh) | Standalone DoH measurement engine |
| [`41-dnstest2-dashboard.sh`](41-dnstest2-dashboard.sh) | SSH login dashboard |
| [`DOH.md`](DOH.md) | DoH implementation notes |
| [`CHANGELOG.md`](CHANGELOG.md) | Version history |

## ⚠️ Measurement notes

- DNS latency depends on the router, ISP, routing, resolver load, and current network conditions.
- A resolver may be fast from one location and slower from another.
- Endpoint availability and provider infrastructure can change over time.
- Run the benchmark more than once if you need a more representative comparison.
- This tool measures response time and basic response validity; it is not a full DNS security, privacy, or DNSSEC audit.

---

<div align="center">

**Flint 2 DNS Benchmark · Version 2**

[Repository](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2) · [Issues](https://github.com/mfranjbar/Flint-2-DNS-Benchmark-2/issues) · [Changelog](CHANGELOG.md)

</div>
