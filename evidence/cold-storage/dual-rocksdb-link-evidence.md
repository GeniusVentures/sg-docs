# Dual-RocksDB Link Evidence (INTG-01, SC1 reinterpretation — v1.1 Phase 7, plan 07-01)

Date: 2026-10-23 · Platform: Windows x64 / MSVC (VS 17 2022) · Tree: `W:/gnus/GeniusNetwork`

## (a) Single pinned RocksDB — ground truth macros

`thirdparty/rocksdb/include/rocksdb/version.h`:

```c
#define ROCKSDB_MAJOR 9
#define ROCKSDB_MINOR 4
#define ROCKSDB_PATCH 0
```

One RocksDB exists in-tree: **9.4.0**.

## (b) Same install tree on all three consumers

Both consumption blocks hint `RocksDB_DIR` at the identical superbuild install
tree (variable naming differs per file convention):

| File | Line | Hint |
|------|------|------|
| `SuperGenius/build/CommonBuildParameters.cmake` | :119 | `set(RocksDB_DIR "${_THIRDPARTY_BUILD_DIR}/rocksdb/lib/cmake/rocksdb")` |
| `GeniusSDK/cmake/CommonBuildParameters.cmake` | :142 | `set(RocksDB_DIR "${THIRDPARTY_BUILD_DIR}/rocksdb/lib/cmake/rocksdb")` |

Both resolve to `W:/gnus/GeniusNetwork/thirdparty/build/Windows/Debug/rocksdb/lib/cmake/rocksdb`
— the same tree the sgns-blockstore package consumes (its package config's
`find_dependency(RocksDB CONFIG)` reuses this hint; the Phase-6 superbuild entry
built sgns-blockstore against the same tree, `thirdparty/build/CommonTargets.cmake`).

Cache-note: `RocksDB_DIR` is set as a NORMAL variable in both files (shadowing),
so `CMakeCache.txt` carries no `RocksDB_DIR` entry in either build tree. The
link-line ground truth below is the authoritative proof.

**Link-line ground truth** — the generated proof-test project
(`SuperGenius/build/Windows/Debug/test/src/crdt/cold_storage_link_proof_test.vcxproj`)
contains exactly ONE rocksdb archive input:

```
W:\gnus\GeniusNetwork\thirdparty\build\Windows\Debug\rocksdb\lib\rocksdb.lib
```

(unique-path scan of the vcxproj link inputs; no second rocksdb path exists)

## (c) No version-pinned RocksDB find

Scan of both consumption blocks for `find_package\s*\(\s*RocksDB\s+[0-9]`:
**zero matches**. Neither block names RocksDB at all — the pre-existing
`find_package(RocksDB CONFIG REQUIRED)` calls (`:120` SuperGenius, `:146`
GeniusSDK) carry no version argument.

## (d) No-second-archive / no-duplicate-symbol evidence

Task 1's clean MSVC link (`windows-on-link-proof.log`): the
`cold_storage_link_proof_test` exe linked with zero `LNK2005` / `LNK1168` /
"already defined" diagnostics while statically linking `sgns-blockstore::sgns-blockstore`
+ RocksDB + the full miniocpp chain into ONE binary. Duplicate-symbol errors are
the observable signature of two RocksDB archives in one link — none occurred.

## (e) Reinterpretation (A1, Pitfall 5)

"Dual RocksDB 9.4/11.1" means the library's **unversioned dual-COMPAT
find posture** (standalone consumer trees at 11.1.2 verified in v1.0;
`SameMajorVersion` note at `thirdparty/sgns-blockstore/CMakeLists.txt:45-49`),
**NOT two RocksDB archives in one binary**. This tree ships exactly one
RocksDB (9.4.0); every consumer and the library share it.
