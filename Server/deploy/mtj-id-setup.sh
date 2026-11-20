#!/usr/bin/env bash
# MTJ plant ID service: BioCLIP-2 on onnxruntime over our species list (zero-shot text + reference photo kNN; models and index
# in $M/refs, built and synced by mtj-id-refs.sh). Rootless podman as user mtj, 127.0.0.1:8092,
# reads the published content pack read-only. Nothing shared with other apps. Idempotent.
set -euo pipefail
B=/opt/mtj/id; M=/var/lib/mtj-db/models
install -d -o mtj -g mtj -m 0750 $M/hf $M/species $M/refs
# The species list from the published content pack (the service never reads the API's files directly).
src=/var/lib/mtj/content/b/$(python3 -c 'import json;print(json.load(open("/var/lib/mtj/content/manifest.json"))["files"]["data/species.json"]["h"])')
cmp -s "$src" $M/species/species.json || install -o mtj -g mtj -m 0640 "$src" $M/species/species.json
[[ ${1:-} == --species-only ]] && exit 0
uid=$(id -u mtj)
u() { (cd /var/lib/mtj-db/home && sudo -u mtj XDG_RUNTIME_DIR=/run/user/$uid "$@"); }
tag=localhost/mtj-id:$(cat $B/*.py $B/Containerfile | sha256sum | cut -c1-12)
[[ -f $M/refs/model/preprocess.json ]] || { echo "mtj-id: no model in $M/refs/model (run mtj-id-refs.sh)"; exit 1; }
cp -r $B /tmp/mtj-id-build && chown -R mtj:mtj /tmp/mtj-id-build
u podman image exists $tag || {
  install -d -o mtj -g mtj /var/lib/mtj-db/tmp
  u env TMPDIR=/var/lib/mtj-db/tmp podman build --isolation=chroot -q -t $tag /tmp/mtj-id-build >/dev/null
}
rm -rf /tmp/mtj-id-build
Q=/var/lib/mtj-db/home/.config/containers/systemd/mtj-id.container
new=$(cat <<UNIT
[Unit]
Description=MyTinyJungle plant ID (BioCLIP)
[Container]
Image=$tag
ContainerName=mtj-id
PublishPort=127.0.0.1:8092:8080
Volume=$M/hf:/models/hf:Z
Volume=$M/species:/species:ro,Z
Volume=$M/refs:/refs:Z
PodmanArgs=--cgroups=disabled --runtime=crun --memory=1600m
[Service]
Restart=always
TimeoutStartSec=1800
[Install]
WantedBy=default.target
UNIT
)
if [[ "$(cat $Q 2>/dev/null)" != "$new" ]]; then
  echo "$new" > $Q; chown mtj:mtj $Q
  u systemctl --user daemon-reload
  u systemctl --user restart mtj-id
  u podman image prune -af >/dev/null 2>&1 || true  # old images (the torch ones were 3+ GB)
fi
echo "id ok"
