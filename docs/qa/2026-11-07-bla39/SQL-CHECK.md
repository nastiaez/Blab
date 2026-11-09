# BLA-39 independent SQL authorization check

2026-11-07 Europe/Berlin. **BLOCKED; 0 executed assertions, 0 passes.**

Migration SHA256: `0cf08d8bbb275de9c0da09f0526ef11aa3070a6c0db959f227bd909904243129`. Worktree HEAD: `ebdcc1d9d19b48d4a7eb0b45bef8290da4fdb31f` with parent-owned uncommitted feature changes. Migration was read, not edited.

## Bounded environment probes
- `docker ps --format '{{.Names}}'`: no response before the enclosing 20-second command timeout (SIGTERM).
- Independent `docker info --format "{{.ServerVersion}}"`: no response before its 10-second timeout (exit 143).
- `docker context show`: `desktop-linux`.
- `command -v psql`: no executable found.
- `df -h .`: 7.8 GiB available at inspection (supersedes earlier approximately 1 GiB estimate).

Docker daemon availability was not established. Therefore no existing DB Config.Image could be inspected, no cached image selected, and no disposable tmpfs DB created. No image pull/build/download, service restart, existing DB/schema mutation, container creation or cleanup occurred. Credentials were not read or exposed.

## Unexecuted required matrix
Upload-prefix RLS; current private object visibility to authorized peer and denial to unrelated peer; expected_actor including null removal; stored object/MIME validation; insert-only Google host/missing/preservation; cleanup grace, current exclusion, lease ownership and claimed-object commit rejection; account-erasure queue ownership/survival are all **UNVERIFIED**. No SQL test script is represented as completed.

The intended minimal auth/storage/profiles bootstrap would be a **narrow fixture, NOT a canonical full migration rebuild**. Neither fixture execution nor canonical rebuild has been achieved. Parent must clear the Docker availability blocker before authorization claims.

## Static observations, not proven migration bugs
The upload filename regex accepts any 36-character sequence of lowercase hex and hyphens rather than a structurally valid UUID. Whether this violates the intended object-name contract needs a product/security decision. Google initialization is INSERT-only and only overwrites when a matching Google URL exists; preserving/removing a photo on later login remains untested. No runtime bug claim is made without execution.
