#!/usr/bin/env bash
# MTJ's own vision model: llama.cpp server (official image) + Qwen2.5-VL 3B (Qwen research licence; free under 100M MAU), rootless podman as
# user mtj, 127.0.0.1:8091 only, 2.5 GB memory cap. Nothing shared with other apps. Idempotent.
set -euo pipefail
M=/var/lib/mtj-db/models
IMG=ghcr.io/ggml-org/llama.cpp:server-b9538
REPO=https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main
install -d -o mtj -g mtj -m 0750 $M
for f in Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf; do
  [[ -s $M/$f ]] || { curl -fL --retry 3 -o $M/$f.part "$REPO/$f" && mv $M/$f.part $M/$f; chown mtj:mtj $M/$f; }
done
uid=$(id -u mtj)
u() { (cd /var/lib/mtj-db/home && sudo -u mtj XDG_RUNTIME_DIR=/run/user/$uid "$@"); }
Q=/var/lib/mtj-db/home/.config/containers/systemd/mtj-ai.container
new=$(cat <<UNIT
[Unit]
Description=MyTinyJungle vision model (llama.cpp + Qwen2.5-VL 3B)
[Container]
Image=$IMG
ContainerName=mtj-ai
PublishPort=127.0.0.1:8091:8080
Volume=$M:/models:ro,Z
Exec=-m /models/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf --mmproj /models/mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf -c 4096 -t 6 --host 0.0.0.0 --port 8080 -np 1
PodmanArgs=--cgroups=disabled --runtime=crun --memory=3584m
[Service]
# Background scene warm-ups yield the CPU to plant ID (mtj-id), which a person is waiting on.
Nice=15
Restart=always
TimeoutStartSec=900
[Install]
WantedBy=default.target
UNIT
)
if [[ "$(cat $Q 2>/dev/null)" != "$new" ]]; then
  echo "$new" > $Q; chown mtj:mtj $Q
  u podman pull -q $IMG >/dev/null
  u systemctl --user daemon-reload
  u systemctl --user restart mtj-ai
fi
echo "ai ok"
