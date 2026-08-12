# Trusted-peer genesis and local trust operations

This runbook establishes the first trusted-peer policy on a new SuperGenius
network and documents the authority boundary after confirmation. Run it from a
controlled operator host with the release-matched `sgns-trust` binary. It is a
manual ceremony, not an enrollment service: participants provide public keys
only, and every later approval is an explicit local operator action.

## Security boundary

- Before first confirmation, the reviewed canonical genesis manifest is the
  trust input. Obtain every participant identity and 128-character public key
  through an already trusted channel such as an in-person meeting, a verified
  video call, or a previously authenticated organizational channel. Verify the
  person and read back the key fingerprint through a second trusted channel.
- Never collect participant private keys. The only bootstrap secret used here
  is a one-use 64-hex-character private key whose derived public key exactly
  matches `bootstrapper_public_key` in the manifest.
- After durable confirmation, the verified records below `DATABASE/trust-state`
  are authoritative. Copies of `trusted_peers`, `bootstrapper_node`, and quorum
  thresholds in JSON are diagnostic only and are non-authoritative.
- Receiving or listing a candidate never signs it. `propose-policy`,
  `propose-burn`, and `approve` are explicit approvals made by the local key
  holder. There is no remote administration endpoint and no automatic approval
  path.

The concrete identities and thresholds shown in this document and in
`example/node_test/sgns_config.json` are **NON-PRODUCTION EXAMPLES ONLY**. They
are non-production values that must not be copied into a deployment or treated
as project authority.

## 1. Freeze the ceremony inputs

Assign one release coordinator and at least two independent reviewers. Record
the release artifact hash, network ID, the existing production CRDT topic,
membership and burn thresholds, and the identity verification evidence for
each participant. Keep the evidence in the organization's access-controlled
audit system; do not put private key material in the evidence.

For `M` unique trusted peers:

- membership threshold must be between `floor(M / 2) + 1` and `M`;
- burn threshold must be between `ceil(2M / 3)`, implemented as `M - floor(M / 3)`, and `M`;
- policy version is `1`, encoding version is `1`, and initial burn is `100`
  basis points for this release.

Every public key must decode to exactly 64 bytes. Normalize it to 128 lowercase
hexadecimal characters, reject duplicates after normalization, and sort the
peer list lexicographically. The bootstrapper public key does not replace a
peer and does not lower either threshold.

Use the following only as a shape reference. The values and thresholds are
**NON-PRODUCTION EXAMPLE VALUES** and all trust fields become
**non-authoritative after confirmation**:

```json
{
  "classification": "NON-PRODUCTION EXAMPLE ONLY - DO NOT DEPLOY",
  "authority_after_confirmation": "none; persisted verified trust state is authoritative",
  "encoding_version": 1,
  "network_id": 144,
  "bootstrapper_public_key": "06a11bcf9223a46514207b0551ed6460140531e8ec94d97a6a1c6bddd1a52da79e04980db3009325837f97ccbd1b1e3fdf05585a4a79ab3d043b7f19bbbc2c80",
  "policy_version": 1,
  "peers": [
    "07b22cde0334a57625318c0662ae7571251642f9dea5ea8b7a2d7ceef2a63eb80d15a092ec410436948108ddce0c2a40ec06696b5b8ab4de154c9020accd3d91",
    "8a33bdf1445a68736429d1773be8682362753a0efc6fb9d8b3e8dffe3b74fc91e26b203fd521547a5219eddf1d3ac51fd17a7646c9bca5ef065da131add4e5a2"
  ],
  "membership_threshold": 2,
  "burn_threshold": 2,
  "initial_burn_basis_points": 100
}
```

For production, create an access-controlled `reviewed-genesis.json` with the
same field names but the verified production values and an accurate production
classification. Require recorded approval of that review source before
encoding it.

## 2. Create identical canonical manifests independently

`sgns-trust` deliberately consumes canonical `GenesisManifest` bytes; it does
not accept JSON and has no manifest-generation or secret-valued command-line
option. On two isolated reviewer workstations, encode the independently
reviewed source with this release-matched reference procedure:

```sh
CEREMONY_DIR=/secure/reviewed/sgns-genesis
test -d "$CEREMONY_DIR"
python3 - "$CEREMONY_DIR/reviewed-genesis.json" "$CEREMONY_DIR/genesis.manifest" <<'PY'
import hashlib
import json
import struct
import sys

source_path, output_path = sys.argv[1:]
with open(source_path, "r", encoding="utf-8") as source_file:
    source = json.load(source_file)

def integer(name, minimum, maximum):
    value = source[name]
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise SystemExit(f"invalid {name}")
    return value

def public_key(value, name):
    if not isinstance(value, str) or len(value) != 128:
        raise SystemExit(f"invalid {name}: expected 128 hexadecimal characters")
    try:
        decoded = bytes.fromhex(value)
    except ValueError as error:
        raise SystemExit(f"invalid {name}: {error}")
    if len(decoded) != 64:
        raise SystemExit(f"invalid {name}: expected 64 decoded bytes")
    return value.lower(), decoded

if integer("encoding_version", 1, 1) != 1:
    raise SystemExit("unsupported encoding version")
network = integer("network_id", 0, 65535)
if integer("policy_version", 1, 1) != 1:
    raise SystemExit("initial policy version must be 1")
if integer("initial_burn_basis_points", 100, 100) != 100:
    raise SystemExit("initial burn basis points must be 100")

bootstrapper_hex, bootstrapper = public_key(source["bootstrapper_public_key"], "bootstrapper_public_key")
raw_peers = source["peers"]
if not isinstance(raw_peers, list) or not 1 <= len(raw_peers) <= 256:
    raise SystemExit("peers must contain between 1 and 256 public keys")
peers = [public_key(value, f"peers[{index}]") for index, value in enumerate(raw_peers)]
peer_hex = sorted(value[0] for value in peers)
if len(set(peer_hex)) != len(peer_hex):
    raise SystemExit("duplicate peer after lowercase normalization")
peer_bytes = [bytes.fromhex(value) for value in peer_hex]

membership = integer("membership_threshold", len(peer_hex) // 2 + 1, len(peer_hex))
burn = integer("burn_threshold", len(peer_hex) - len(peer_hex) // 3, len(peer_hex))

def lp(value):
    return struct.pack(">I", len(value)) + value

manifest = b"SGNS_TRUST_GENESIS_V1"
manifest += struct.pack(">BH", 1, network)
manifest += lp(bootstrapper)
manifest += struct.pack(">QI", 1, len(peer_bytes))
manifest += b"".join(lp(value) for value in peer_bytes)
manifest += struct.pack(">QQQ", membership, burn, 100)

with open(output_path, "wb") as output_file:
    output_file.write(manifest)
print("ordered peers:")
for value in peer_hex:
    print(f"  {value}")
print(f"fingerprint: {hashlib.sha256(manifest).hexdigest()}")
PY
chmod 0444 "$CEREMONY_DIR/genesis.manifest"
openssl dgst -sha256 "$CEREMONY_DIR/genesis.manifest"
```

The byte layout above mirrors `GenesisManifest::CanonicalBytes`: domain
`SGNS_TRUST_GENESIS_V1`, fixed-width big-endian integers, 32-bit big-endian
length prefixes, and lexicographically ordered lowercase 64-byte peer keys.
Do not hand-edit `genesis.manifest`.

Compare all of the following between reviewers over a separate trusted channel:

1. the ordered peer list;
2. network ID, bootstrapper public key, policy version, both thresholds, and
   initial burn value;
3. the 64-character lowercase SHA-256 fingerprint;
4. the hash of the exact `sgns-trust` release binary.

Stop if any value differs. Copy the approved, read-only manifest to each
ceremony host and verify its SHA-256 fingerprint again after transfer.

## 3. Prepare the runtime and bootstrap key

Set paths explicitly. `TOPIC` must be an already deployed production CRDT
topic; this command creates no alternate genesis topic. `DATABASE` is the
node's production GlobalDB path, and its trust anchor will be stored beneath
`DATABASE/trust-state`. Stop any process that already owns that database before
running local administration.

```sh
SGNS_TRUST=/opt/supergenius/bin/sgns-trust
MANIFEST="$CEREMONY_DIR/genesis.manifest"
NETWORK_CONFIG=/etc/supergenius/network_config.json
DATABASE=/var/lib/supergenius/globaldb
TOPIC=sgns-production-existing-topic

test -x "$SGNS_TRUST"
test -r "$MANIFEST"
test -r "$NETWORK_CONFIG"
"$SGNS_TRUST" --help
```

Generate the one-use bootstrap key with the organization's approved offline
key process. Independently authenticate its public key and ensure it is exactly
the manifest's `bootstrapper_public_key`. Never pass a private key in argv, an
environment variable, a command substitution, a pipe, or a log command.

Choose exactly one protected input method:

- `--key-stdin` reads from an interactive terminal with echo disabled. A pipe
  or redirected stdin is rejected. The tool cleanses its in-process copy, but
  cannot erase the operator's original offline key material.
- `--key-file PATH` requires an owner-controlled, regular, non-symlink file
  with mode exactly `0600`. Verify the staged file before use:

```sh
KEY_FILE=/secure/volatile/sgns-bootstrap.key
test -f "$KEY_FILE"
test ! -L "$KEY_FILE"
chmod 0600 "$KEY_FILE"
test "$(stat -f '%Lp' "$KEY_FILE" 2>/dev/null || stat -c '%a' "$KEY_FILE")" = 600
```

The key file must contain only the 64 hexadecimal private-key characters, with
an optional final line ending. Do not stage it in the database, repository,
manifest directory, backups, or audit evidence.

## 4. Review and submit genesis

Preferred interactive-terminal command:

```sh
"$SGNS_TRUST" genesis \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC" \
  --key-stdin \
  --timeout-seconds 600
```

Protected-file alternative:

```sh
"$SGNS_TRUST" genesis \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC" \
  --key-file "$KEY_FILE" \
  --timeout-seconds 600
```

The tool decodes the file canonically before reading the secret and prints this
review surface: network, bootstrapper, policy version, membership threshold,
burn threshold, initial burn basis points, ordered peers, and fingerprint.
Compare that screen with the signed audit record. The derived bootstrapper key
must also match the manifest.

At `Type the exact fingerprint to submit:`, type or paste the complete reviewed
64-character lowercase fingerprint. This exact fingerprint is the typed
confirmation; any extra character or mismatch aborts before submission.

Success is only the final line:

```text
Genesis durably confirmed.
```

That line is emitted only after `DATABASE/trust-state` loads a verified durable
snapshot whose canonical genesis and fingerprint exactly match the reviewed
manifest. Record the exit status, the non-secret review output, timestamp,
release binary hash, manifest fingerprint, topic, and confirmation line as the
ceremony evidence.

For `--key-file`, the tool cleanses its in-process copy and unlinks the file
only after durable confirmation. Verify success-only cleanup:

```sh
test ! -e "$KEY_FILE"
```

If the command fails, times out, or prints a `CRITICAL` retention message, the
file is intentionally retained. Do not delete it or start a new genesis. Keep
it protected, investigate the network/database state and fingerprint, then
retry only the identical reviewed ceremony. If confirmation succeeded but
unlink failed, securely remove the residual file before continuing. File
unlink is not guaranteed physical secure deletion on flash storage, journaled
filesystems, snapshots, swap, or backups; use encrypted volatile storage and
the organization's media-destruction procedure where that distinction matters.

## 5. Verify restart authority and alerts

Restart the node with the same network and database. A confirmed node must load
the persisted verified policy and burn heads before enabling economic work.
Mutable JSON trust copies do not become authoritative again:

- `TRUST_CONFIG_CONFLICT` is a critical diagnostic when `trusted_peers`,
  `bootstrapper_node`, `trusted_peer_quorum_threshold`, or
  `burn_config_quorum_threshold` conflicts. The persisted last-known-good (LKG)
  state remains active; canonical peer reordering alone is not a conflict.
- `TRUST_NETWORK_MISMATCH` is fatal. Do not override it or point the process at
  another network's trust store.
- `TRUST_LOCAL_STATE_CORRUPT` is fatal. Restore only from an authenticated,
  matching checkpoint and investigate before reconnecting.
- `TRUST_CRDT_MISSING`, `TRUST_CRDT_ROLLBACK`, and `TRUST_CRDT_FORK` are
  operational alerts. Missing, older, or same-version conflicting replicated
  data does not erase or replace the persisted LKG policy and burn heads.

Only a correctly versioned descendant linked to the current persisted policy
hash and confirmed under the current signer set can replace LKG state. Preserve
the persisted fingerprint and alert code in incident evidence; do not delete
`trust-state` to silence an alert.

### Accepted whole-disk rollback boundary

Software-only checks cannot detect an administrator or attacker restoring the
whole database **and every local anchor** to one mutually consistent older disk
snapshot. They also cannot guarantee physical erasure of key bytes already
copied into lower storage layers. Detecting that whole-disk rollback requires
an anchor outside the restored image, such as TPM-backed monotonic state, an
OS-keystore monotonic counter, or authenticated off-host checkpoints. This is
an accepted deployment boundary, not a recovery technique. Production owners
must choose and monitor at least one external anchor if whole-disk restoration
is in their threat model.

## 6. List, propose, and explicitly approve successors

Run these commands locally during a database maintenance window with the same
release binary, canonical genesis manifest, network config, database, and
production topic. `list` needs no key and never signs:

```sh
"$SGNS_TRUST" list \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC"
```

It prints authenticated candidates at the current head as either `policy` or
`burn`, followed by an exact content-addressed candidate ID of the form
`domain:version:64-lowercase-hex-hash`. Empty output means there is no current
candidate to review.

To propose a membership/quorum-policy successor, obtain independently reviewed
canonical `QuorumPolicyState` bytes from the controlled release process. The
current `sgns-trust` surface validates and submits those canonical bytes but
intentionally does not build them and does not accept policy JSON. The artifact
must use the release codec domain `SGNS_TRUST_POLICY_V1`, advance the current
version by exactly one, and bind both its expected predecessor and authorizing
policy hashes to the current policy hash. Then make the proposer's explicit
first approval:

```sh
"$SGNS_TRUST" propose-policy \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC" \
  --candidate /secure/reviewed/policy-successor.bin \
  --key-stdin
```

To propose a burn successor, review the decimal basis-point value and make the
proposer's explicit first approval:

```sh
"$SGNS_TRUST" propose-burn \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC" \
  --basis-points 125 \
  --key-stdin
```

The `125` value above is a **NON-PRODUCTION EXAMPLE ONLY** and is not an
authorized economic setting. A successful proposal prints its exact candidate
ID and adds only the local trusted peer's explicit approval.

After independently checking the candidate bytes or basis points, version,
current predecessor hash, candidate ID, and policy floor, another authorized
operator explicitly approves that exact ID:

```sh
"$SGNS_TRUST" approve \
  --manifest "$MANIFEST" \
  --network-config "$NETWORK_CONFIG" \
  --database "$DATABASE" \
  --topic "$TOPIC" \
  --candidate-id 'trusted-peer:2:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' \
  --key-stdin
```

The candidate ID above is a **NON-PRODUCTION EXAMPLE ONLY**. Copy the real ID
from the reviewed proposal/list output; approval signatures are bound to that
exact ID and cannot authorize a competing candidate. Proposal and approval
attempt durable activation after the explicit signature; a below-quorum
candidate remains pending. Competing same-version candidates become stale once
one reaches quorum.

For ordinary trusted-peer operations, `--key-file` is also supported with the
same owner/regular-file/non-symlink/`0600` checks. Unlike the one-shot `genesis`
operation, administration commands do **not** unlink a trusted peer's key file.
The in-process key string is cleansed, but custody and lifecycle remain the key
holder's responsibility.

## Command-surface audit

The shipped command has exactly these local operations:

```text
genesis
list
propose-policy
propose-burn
approve
```

All operations require `--manifest`, `--network-config`, `--database`, and
`--topic`. Every operation except `list` requires exactly one of `--key-file`
or `--key-stdin`; `genesis` alone accepts `--timeout-seconds`,
`propose-policy` requires `--candidate`, `propose-burn` requires
`--basis-points`, and `approve` requires `--candidate-id`. There is no
`--private-key`, `--secret`, token, environment-secret, HTTP, RPC, or remote
auto-approval option.

The command forms documented above are the literal shipped surface:
`sgns-trust genesis`, `sgns-trust list`, `sgns-trust propose-policy`,
`sgns-trust propose-burn`, and `sgns-trust approve`. A packaged or installed
binary may be invoked through an absolute path as shown in the procedure.
