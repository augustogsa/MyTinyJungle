#!/usr/bin/env bash
# Concurrent public reads against the API. Usage: loadtest.sh [base] [requests] [workers]
set -euo pipefail
BASE=${1:-https://api.mytinyjungle.com}; N=${2:-600}; C=${3:-30}
out=$(mktemp); trap 'rm -f "$out"' EXIT
paths=(/health /v1/content/manifest /health)
seq "$N" | xargs -P "$C" -I{} sh -c 'p=$(echo "'"${paths[*]}"'" | tr " " "\n" | sed -n "$(( {} % 3 + 1 ))p"); curl -s -o /dev/null -w "%{http_code} %{time_total}\n" "'"$BASE"'$p"' >> "$out"
total=$(wc -l < "$out"); err=$(awk '$1>=500||$1==0' "$out" | wc -l)
p95=$(awk '{print $2}' "$out" | sort -n | awk '{a[NR]=$1} END{print a[int(NR*0.95)]}')
echo "requests=$total 5xx=$err p95=${p95}s"
awk -v p="$p95" -v e="$err" 'BEGIN{exit !(p<0.8 && e==0)}'
