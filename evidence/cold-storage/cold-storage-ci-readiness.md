# Cold-Storage CI Readiness (v1.1 Phase 7, plan 07-01 Task 2 — feeds 07-03's ON-lane branch)

verdict=stale

## Observation

- Newest `GeniusVentures/thirdparty` release tag: **`test_tokenprice`**
  (all assets created 2026-10-05).
- `Windows-Debug.tar.gz` (795,558,861 bytes, sha256 digest
  `9e1e59e3f84efe4459f8f67e6e8986d45ef71e7f2386ba1e2b64178b59037a9cbc`,
  downloaded and listed 2026-10-23) layout: `build/Windows/Debug/<component>/`.
- Listing results:
  - `build/Windows/Debug/json/share/cmake/nlohmann_json/` — **present**
  - `build/Windows/Debug/sgns-blockstore/` — **ABSENT**
  - `build/Windows/Debug/minio-cpp/` — **ABSENT**
  - `build/Windows/Debug/pugixml/` — **ABSENT**

Corroborated by superbuild history (`git -C thirdparty log`):
`sgns-blockstore` entered the superbuild 2026-10-20 (`47939d6`),
`minio-cpp@v1.0.0 + pugixml@v1.16` on 2026-10-21 (`a2461c4`) — both AFTER
the 2026-10-05 tag, so the tarball cannot contain them.

## Decision rule (from 07-01-PLAN Task 2)

- `fresh`  → 07-03 wires the CI ON-lane against the released tarball.
- `stale`  → 07-03 documents the ON-lane as **blocked-on-release-cut** with the
  local superbuild evidence standing in (v1.0 pattern) and files the release
  cut as a follow-up.  ← **this verdict**
- `unverified` (gh/network unavailable) → record the exact command for the user
  and treat as stale.

## Consequence for plan 07-03

The CI Tier-1 lane addition lands in the default (OFF) lane; any SGNS_COLD_STORAGE=ON
CI lane is documented as blocked-on-release-cut until a thirdparty release is cut
that includes the Phase-6 install trees (`sgns-blockstore/`, `minio-cpp/`,
`pugixml/` under `build/<Platform>/<Config>/`). Follow-up filed: cut a new
`GeniusVentures/thirdparty` release after pushing the thirdparty submodule
pointer (post-phase, no-push constraint applies during the phase).

Re-verification command after a release cut:

```
gh release view --repo GeniusVentures/thirdparty --json tagName,assets
# then download the platform tarball and list for:
#   build/<Platform>/<Config>/{sgns-blockstore,minio-cpp,pugixml}/
```

## CI ON-lane disposition (07-03 Task 2, 2026-10-23)

**Status: blocked-on-thirdparty-release-cut.** Per the stale-verdict decision
rule above, plan 07-03 did NOT wire an SGNS_COLD_STORAGE=ON CI job: the
released tarball lacks the Phase-6 install trees, so every ON configure
would fail at the find. The committed local superbuild evidence stands in
(v1.0 pattern):

- Windows ON configure/build/link/ctest proof: `windows-on-link-proof.log`
- GeniusSDK ON configure proof: `genius-sdk-on-configure.log`

**Follow-up (post-phase, requires push):** cut a `GeniusVentures/thirdparty`
release containing the Phase-6 install trees (push the thirdparty submodule
pointer, run the release workflow), re-run the re-verification command
above, then wire the ON-lane leg (configure with `-DSGNS_COLD_STORAGE=ON`
against the released `THIRDPARTY_BUILD_DIR`, build
`cold_storage_link_proof_test`, run `ctest -L Tier1 --no-tests=error`).

## Phase-8 disposition (08-03 Task 2, 2026-10-24)

**Status: unchanged — ON-lane still blocked-on-thirdparty-release-cut.**

The Phase-8 spill tests (`cold_storage_spill_test`: 13 cases — journal
contract, drain-to-S3, crash-restart reconciliation, s3d-down backpressure
window, enqueue-never-inline, shutdown grace, degenerate inputs, SC1
latency-independence benchmark, partial-success backoff) are
`SGNS_COLD_STORAGE`-gated in `SuperGenius/test/src/crdt/CMakeLists.txt`
because they link `sgns-blockstore::sgns-blockstore` — the same structural
reason as the Phase-7 link proof. The release-cut verdict above is
therefore NOT re-evaluated this phase: the newest `thirdparty` release
still predates the Phase-6 install trees, and every CI ON configure would
fail at the find. No `cmake.yml` change was made in Phase 8.

The local Windows ON-lane Tier-1 evidence stands in (v1.0/Phase-7
pattern), produced from the local superbuild install tree:

```
ctest --test-dir SuperGenius/build/Windows/Debug -C Debug -L Tier1 --no-tests=error
# 100% tests passed, 0 tests failed out of 3   (2026-10-24)
#   cold_storage_config_gate_test  (unconditional; 26 matrix cases)
#   cold_storage_link_proof_test   (gated; Phase 7)
#   cold_storage_spill_test        (gated; Phase 8, 13 cases)
```

The CI ON-lane flip (Open Question 1, 08-RESEARCH) remains blocked on the
SAME release cut with the SAME re-verification command — see the block
above. Do not weaken or reinterpret this rule without a fresh tarball
listing.
