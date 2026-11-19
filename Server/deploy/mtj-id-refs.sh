#!/usr/bin/env bash
# Rebuilds the plant ID reference index (Wikimedia Commons CC/PD photos per species -> BioCLIP embeddings), tunes
# the text/kNN blend by leave-one-out on the references (never on the eval set) and syncs refs.npz, refs.json and
# params.json to /var/lib/mtj-db/models/refs on the VPS, where mtj-id picks them up without a restart.
# Runs on any machine with uv (the VPS has no spare RAM for a second model copy). Resumable.
#   bash Server/deploy/mtj-id-refs.sh            # fetch new species, embed, tune, sync
set -euo pipefail
cd "$(dirname "$0")/../.."
W=${MTJ_REFS_WORK:-$HOME/.cache/mtj-refs}; H=${MTJ_HOST:-mdm-ovh}
mkdir -p "$W"
[[ -x "$W/venv/bin/python" ]] || { uv venv -q -p 3.11 "$W/venv"; uv pip install -q -p "$W/venv" torch open_clip_torch pillow numpy; }
P="$W/venv/bin/python -I Server/deploy/mtj-id/refs.py"
$P fetch Content/data/species.json "$W/cache"
$P embed Content/data/species.json "$W/cache" "$W/out"
$P tune  Content/data/species.json "$W/cache" "$W/out"
scp -q "$W/out/refs.npz" "$W/out/refs.json" "$W/out/params.json" "$H:/tmp/"
ssh "$H" 'sudo install -o mtj -g mtj -m 0640 /tmp/refs.npz /tmp/refs.json /tmp/params.json /var/lib/mtj-db/models/refs/ && rm -f /tmp/refs.npz /tmp/refs.json /tmp/params.json'
echo "refs synced"
