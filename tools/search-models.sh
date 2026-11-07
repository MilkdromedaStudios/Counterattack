#!/usr/bin/env bash
# Search Creator Store models via the Open Cloud Toolbox Service.
#
#   tools/search-models.sh "<query>" [count]      (count: 1-100, default 20)
#
# Output, one result per line, tab-separated:
#   <assetId>  <name>  <creator>  <verified|unverified>  <scripts:N|scripts:?>
#
# Endpoint: POST https://apis.roblox.com/toolbox-service/v2/assets:search
# Scope:    creator-store-product:read
# Docs:     https://create.roblox.com/docs/cloud/reference/features/creator-store
#
# ROBLOX_API_KEY is passed to curl on stdin, never on the command line.
set -euo pipefail

die() { printf 'search-models: error: %s\n' "$*" >&2; exit 1; }

[[ $# -ge 1 && $# -le 2 && -n $1 ]] || die 'usage: tools/search-models.sh "<query>" [count]'
query=$1
count=${2:-20}
[[ $count =~ ^[0-9]+$ ]] && (( count >= 1 && count <= 100 )) || die "count must be 1-100"
[[ -n ${ROBLOX_API_KEY:-} ]] || die "ROBLOX_API_KEY is not set"
command -v jq >/dev/null || die "jq is not installed"

tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT

body=$(jq -n --arg q "$query" --argjson n "$count" \
  '{searchCategoryType: "Model", query: $q, maxPageSize: $n, searchView: "Full"}')

status=$(
  printf 'x-api-key: %s\n' "$ROBLOX_API_KEY" |
    curl -sS --compressed -o "$tmp" -w '%{http_code}' -X POST \
      -H @- -H 'Content-Type: application/json' -H 'Accept: application/json' \
      --data "$body" \
      'https://apis.roblox.com/toolbox-service/v2/assets:search'
) || die "request to Toolbox Service failed (network error)"

if [[ $status != 200 ]]; then
  msg=$(jq -r '[.errors[]?.message, .message?] | map(select(. != null)) | join("; ")' "$tmp" 2>/dev/null || true)
  case $status in
    401) hint="API key rejected" ;;
    403) hint="key lacks the creator-store-product:read scope" ;;
    429) hint="rate limited, wait and retry" ;;
    *)   hint="unexpected response" ;;
  esac
  die "HTTP $status from Toolbox Service: $hint${msg:+ ($msg)}"
fi

jq -e '.creatorStoreAssets | type == "array"' "$tmp" >/dev/null 2>&1 \
  || die "unexpected response shape (no creatorStoreAssets array)"

n=$(jq '.creatorStoreAssets | length' "$tmp")
if (( n == 0 )); then
  printf 'search-models: no results for "%s"\n' "$query" >&2
  exit 0
fi

# hasScripts/scriptCount live on the Model sub-object; its exact path is not
# pinned down in the docs, so check the likely places.
jq -r '
  .creatorStoreAssets[] |
  ((.asset.model // .asset.modelDetails // .asset) as $m |
   [ (.asset.id // "?" | tostring),
     ((.asset.name // "?") | gsub("[\t\n]"; " ")),
     (.creator.name // "?"),
     (if .creator.verified == true then "verified" else "unverified" end),
     (if $m.scriptCount != null then "scripts:\($m.scriptCount)"
      elif $m.hasScripts == true then "scripts:yes"
      elif $m.hasScripts == false then "scripts:0"
      else "scripts:?" end)
   ] | @tsv)
' "$tmp"
