#!/usr/bin/env bash
# Exports BioCLIP-2 to ONNX (int8 image encoder) once, rebuilds the plant ID reference index (Wikimedia Commons CC/PD photos per
# species, plus iNaturalist CC phone photos in inat.npz -> embeddings with that same encoder), tunes
# the text/kNN blend by leave-one-out on the references (never on the eval set) and syncs refs.npz, refs.json and
# params.json to /var/lib/mtj-db/models/refs on the VPS, where mtj-id picks them up without a restart.
# Runs on any machine with uv (the VPS has no spare RAM for a second model copy). Resumable.
#   bash Server/deploy/mtj-id-refs.sh            # fetch new species, embed, tune, sync
set -euo pipefail
cd "$(dirname "$0")/../.."
W=${MTJ_REFS_WORK:-$HOME/.cache/mtj-refs}; H=${MTJ_HOST:-mdm-ovh}
mkdir -p "$W"
[[ -x "$W/venv/bin/python" ]] || { uv venv -q -p 3.11 "$W/venv"; uv pip install -q -p "$W/venv" torch open_clip_torch onnx onnxruntime onnxscript ftfy regex pillow numpy; }
PY="$W/venv/bin/python -I"; P="$PY Server/deploy/mtj-id/refs.py"
[[ -f "$W/model/visual.int8.onnx" ]] || MODEL=hf-hub:imageomics/bioclip-2 $PY Server/deploy/mtj-id/export_onnx.py "$W/model"
$P fetch Content/data/species.json "$W/cache"
$P embed Content/data/species.json "$W/cache" "$W/out" "$W/model"
$P tune  Content/data/species.json "$W/cache" "$W/out" "$W/model"
$PY Server/deploy/mtj-id/inat.py fetch Content/data/species.json "$W/inat" Server/eval/identify.json
$PY Server/deploy/mtj-id/inat.py embed "$W/inat" "$W/model" "$W/out"
R=/var/lib/mtj-db/models/refs
ssh "$H" "sudo install -d -o mtj -g mtj -m 0750 $R/model"
for f in visual.int8.onnx text.onnx preprocess.json; do  # the model only when it changed
  [[ $(ssh "$H" "sudo sha256sum $R/model/$f 2>/dev/null | cut -c1-64") == $(shasum -a 256 "$W/model/$f" | cut -c1-64) ]] || { scp -q "$W/model/$f" "$H:/tmp/$f" && ssh "$H" "sudo install -o mtj -g mtj -m 0640 /tmp/$f $R/model/ && rm -f /tmp/$f"; }
done
scp -q "$W/out/refs.npz" "$W/out/refs.json" "$W/out/params.json" "$W/out/inat.npz" "$W/out/inat.json" "$H:/tmp/"
ssh "$H" "cd /tmp && sudo install -o mtj -g mtj -m 0640 refs.npz refs.json params.json inat.npz inat.json $R/ && rm -f refs.npz refs.json params.json inat.npz inat.json"
echo "model and refs synced"
