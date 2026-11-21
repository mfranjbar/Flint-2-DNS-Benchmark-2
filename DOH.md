# DoH module

The module is ported from the previous v2 development branch and runs independently from the v1 installation. It tests 26 configured DoH endpoints using RFC 8484 DNS wire format and the reference site's 12 hostnames, with one warm-up round and two measured rounds. TLS certificates and DNS transaction IDs are checked. Failed measured queries receive a 5000 ms penalty. It exports machine-readable results to the orchestrator through DNSTEST_RAW_OUT.

No DNS, firewall, routing or service settings are changed.
