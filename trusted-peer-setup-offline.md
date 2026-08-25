# Trusted Setup — Offline Runbook

One page, no commentary. Full context: `trusted-peer-genesis.md`.
Values below are placeholders — replace with the agreed production values.

**Agreed inputs (freeze before starting):**

- network ID: `144`
- bootstrapper address (operator's): `<128-hex>`
- peers: `<addr-1>`, `<addr-2>`, ... `M` total
- thresholds: membership `floor(M/2)+1`, burn `M - floor(M/3)` (or higher, up to `M`)
- fixed: policy version `1`, initial burn `100` (1%)

---

## Maintainers

1. Send your node address (128-hex public key) to the coordinator via a trusted
   channel. Never send your private key or mnemonic.
2. Receive the trust block. Check your address is in `trusted_peers`.
3. Add it to `sgns_config.json` (keep your `net_id`/`subnet_id`):

   ```json
   "trusted_peers": ["<addr-1>", "<addr-2>", "..."],
   "bootstrapper_node": "<bootstrapper address>",
   "trusted_peer_quorum_threshold": 3,
   "burn_config_quorum_threshold": 4
   ```

   Every maintainer must run byte-identical values. A mismatching node rejects
   the genesis.
4. Upgrade to the release build and start the node. It parks in
   `WAITING_FOR_TRUST_GENESIS` — expected; leave it running.
5. Done. When the coordinator submits the genesis, your node validates,
   persists, self-approves the burn, and reaches `READY` by itself. Restarts
   reload the persisted genesis — no ceremony again.

---

## Coordinator (operator)

Run from a controlled host with the release-matched `sgns-trust`. The
bootstrapper private key is used exactly once.

1. Collect all maintainer addresses (trusted channel, verified out-of-band).
2. Build the manifest:

   ```sh
   sgns-trust make-manifest \
     --network-id 144 \
     --bootstrapper <your 128-hex address> \
     --peers <addr-1>,<addr-2>,<addr-3> \
     --out genesis.manifest
   ```

   Thresholds default to the floors; add `--membership-threshold` /
   `--burn-threshold` only to raise them. Record the printed fingerprint and
   send it to all maintainers for cross-check.
3. Stage the one-use key (64-hex private key of the bootstrapper address):

   ```sh
   printf '<64-hex private key>\n' > genesis.key && chmod 600 genesis.key
   ```

4. Write `tool_network.json` (points the tool at the live network):

   ```json
   {"pubsub_port":"0","pubsub_bind_address":"0.0.0.0","auto_dht":false,
    "bootstrap_addresses":["<multiaddr of the running bootstrap node>"]}
   ```

5. Submit the genesis:

   ```sh
   sgns-trust genesis \
     --manifest genesis.manifest \
     --network-config tool_network.json \
     --database ./trust-tool-db \
     --topic SuperGNUSNode.TestNet.FullNode \
     --key-file genesis.key \
     --timeout-seconds 600
   ```

6. Read the printed review surface line by line (network, peers, thresholds,
   bootstrapper). Type the exact 64-char fingerprint to confirm.
7. Success is only the final line: `Genesis durably confirmed.`
   The tool deletes `genesis.key`. Verify: `test ! -e genesis.key`.
   On failure/timeout/`CRITICAL` the file is intentionally kept — do not
   delete it, do not start a different genesis; fix the cause and retry the
   identical ceremony.
8. Confirm every maintainer node reached `READY`. Optional check:

   ```sh
   sgns-trust list --manifest genesis.manifest \
     --network-config tool_network.json --database ./trust-tool-db2 \
     --topic SuperGNUSNode.TestNet.FullNode
   ```

---

## After the setup

- The persisted `trust-state` on each node is authoritative; the JSON trust
  keys become diagnostic only.
- Membership/threshold/burn changes: `propose-policy` / `propose-burn` /
  `approve`, signed by current trusted peers. The bootstrapper key is gone and
  never needed again.
- Fatal alerts: `TRUST_NETWORK_MISMATCH`, `TRUST_LOCAL_STATE_CORRUPT` — stop
  and investigate; never delete `trust-state` to silence an alert.
