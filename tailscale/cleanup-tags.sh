#!/usr/bin/env bash
set -uo pipefail

TAILSCALE_API_KEY="${TAILSCALE_API_KEY:-}"
TAILNET="${TAILNET:-}"
DRY_RUN="${DRY_RUN:-1}"

if [[ -z "$TAILSCALE_API_KEY" ]]; then
  echo "TAILSCALE_API_KEY is required." >&2
  exit 1
fi

if [[ -z "$TAILNET" ]]; then
  if command -v tailscale >/dev/null 2>&1; then
    TAILNET="$(tailscale status --json | jq -r '.CurrentTailnet.MagicDNSSuffix // empty')"
  fi
fi

if [[ -z "$TAILNET" ]]; then
  echo "TAILNET is required (example: ktz.ts.net)." >&2
  exit 1
fi

REMOVE_TAGS=(
  "tag:rdu"
  "tag:rdu-px"
  "tag:rdu-sr"
  "tag:norfolk-sr"
  "tag:ca-ont"
  "tag:cloud"
  "tag:zfs-replication"
  "tag:family-share"
  "tag:exitnode"
  "tag:use-exitnode"
)

remove_json="$(printf '%s\n' "${REMOVE_TAGS[@]}" | jq -R . | jq -s .)"

devices_json="$(curl -fsS -u "${TAILSCALE_API_KEY}:" \
  "https://api.tailscale.com/api/v2/tailnet/${TAILNET}/devices")"

updates="$(
  echo "$devices_json" | jq -r --argjson remove "$remove_json" '
    .devices[]
    | {id, name, tags: (.tags // [])}
    | . as $d
    | ($d.tags - $remove) as $newtags
    | select(($d.tags|length) != ($newtags|length))
    | {id: $d.id, name: $d.name, tags: $newtags}
    | @base64
  '
)"

if [[ -z "$updates" ]]; then
  echo "No devices found with removable tags."
  exit 0
fi

echo "Tailnet: $TAILNET"
echo "Remove tags: ${REMOVE_TAGS[*]}"
echo ""

while read -r row; do
  obj="$(echo "$row" | base64 --decode)"
  id="$(echo "$obj" | jq -r '.id')"
  name="$(echo "$obj" | jq -r '.name')"
  tags="$(echo "$obj" | jq -c '.tags')"

  if [[ "$DRY_RUN" != "0" ]]; then
    echo "DRY RUN: $name ($id) -> $tags"
    continue
  fi

  resp_file="$(mktemp)"
  http_code="$(
    curl -sS -u "${TAILSCALE_API_KEY}:" \
      -H "Content-Type: application/json" \
      -d "{\"tags\":$tags}" \
      -o "$resp_file" \
      -w "%{http_code}" \
      "https://api.tailscale.com/api/v2/device/${id}/tags" || true
  )"

  if [[ "$http_code" == "200" || "$http_code" == "204" ]]; then
    echo "Updated: $name ($id)"
  else
    echo "ERROR: $name ($id) -> HTTP $http_code" >&2
    if [[ -s "$resp_file" ]]; then
      echo "Response: $(cat "$resp_file")" >&2
    fi
  fi

  rm -f "$resp_file"
done <<< "$updates"
