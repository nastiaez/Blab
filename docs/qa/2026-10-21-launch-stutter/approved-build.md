# Approved original-motion build

Motion approval:15044 (actual clip15028). Application build request:15048.
Original animation source04524dc; only leading/solo-a idle removed.
Implementation0b6305a; reconciled runtime441f544 at current origin/main9bf8494.
Existing preview-only tools and rejected candidate evidence excluded from commit.
Full integrated tests/analysis and signed Android34 verification pending.
Build-only scope: do not distribute or change remote notices/backends.


## Integrated signed Android34 result

Approved runtime459afbf integrated/pushed, implementation0b6305a reachable.
Reconciled full1031 pass/16 environment skips; analysis clean. Built real
lib/main.dart, signed staging/test Android34, no preview overrides. Signer matches
33; exact replacement33→34 retains firstInstallTime and selectedDE across cold
restart. Fresh task-owned emulator5580 avoids data-bearing/shared devices.

Actual native cold launch through resolved Welcome recorded and inspected;
recording delivered15060. HOT return also recorded/inspected: no logo replay.
This verifies signed-out Welcome handoff, not authenticated Chats or physical
phone/iOS acceptance.790ms is decorative motion only, not OS launch/readiness.

Artifact SHA256:5a4bc717519179581b01d3477cc7e57590e891ebf4c3c4e796d978fdcb5ae385.
Canonical APK, screenshots, recordings, test/build logs and receipt are retained
in parent releases/20261021-launch34/. Build-only request completed: NOT
uploaded/distributed; no notices, backends or production changed.
