#!/usr/bin/env bash
# Download a Creator Store model as .rbxm via the Open Cloud Asset Delivery API.
#
#   tools/fetch-model.sh <assetId> <output.rbxm>
#
# Needs ROBLOX_API_KEY in the environment (scope: legacy-asset:manage / asset
# delivery read). The key is passed to curl on stdin, never on the command line,
# so it never shows up in `ps`, shell history, logs, or files.
#
# Docs: https://create.roblox.com/docs/cloud/reference/domains/assetdelivery
set -euo pipefail

die() { printf 'fetch-model: error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 2 ]] || die "usage: tools/fetch-model.sh <assetId> <output.rbxm>"
asset_id=$1
out=$2

[[ $asset_id =~ ^[0-9]+$ ]] || die "assetId must be a number, got '$asset_id'"
[[ $out == *.rbxm ]] || die "output must end in .rbxm, got '$out'"
[[ -n ${ROBLOX_API_KEY:-} ]] || die "ROBLOX_API_KEY is not set"
command -v jq >/dev/null || die "jq is not installed"
command -v curl >/dev/null || die "curl is not installed"

out_dir=$(dirname -- "$out")
[[ -d $out_dir ]] || die "output directory '$out_dir' does not exist"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

# 1. Ask Asset Delivery where the asset lives. Header comes from stdin (-H @-).
status=$(
  printf 'x-api-key: %s\n' "$ROBLOX_API_KEY" |
    curl -sS --compressed -o "$tmp/meta.json" -w '%{http_code}' \
      -H @- -H 'Accept: application/json' \
      "https://apis.roblox.com/asset-delivery-api/v1/assetId/${asset_id}"
) || die "request to Asset Delivery API failed (network error)"

if [[ $status != 200 ]]; then
  msg=$(jq -r '[.errors[]?.message, .message?] | map(select(. != null)) | join("; ")' \
    "$tmp/meta.json" 2>/dev/null || true)
  case $status in
    401) hint="API key rejected (wrong key, expired, or IP not allowed)" ;;
    403) hint="key lacks the asset delivery permission, or the asset is not accessible to you" ;;
    404) hint="asset $asset_id not found" ;;
    429) hint="rate limited, wait and retry" ;;
    *)   hint="unexpected response" ;;
  esac
  die "HTTP $status from Asset Delivery: $hint${msg:+ ($msg)}"
fi

location=$(jq -r '.location // empty' "$tmp/meta.json" 2>/dev/null) \
  || die "Asset Delivery response was not JSON"
if [[ -z $location ]]; then
  errs=$(jq -c '.errors // empty' "$tmp/meta.json" 2>/dev/null || true)
  die "response had no \"location\" field${errs:+, errors: $errs}"
fi
[[ $location == https://* ]] || die "location is not an https URL"

# 2. Download from the CDN. The API key is NOT sent here.
curl -sSfL --compressed -o "$tmp/asset.bin" "$location" \
  || die "download from CDN location failed"

# 3. Sanity-check it is actually a Roblox model file.
magic=$(head -c 8 "$tmp/asset.bin" | tr -d '\0')
case $magic in
  '<roblox!'*) ;;                          # binary .rbxm
  '<roblox '*|'<roblox'*) ;;               # XML model
  *) die "downloaded file is not a Roblox model (starts with: $(head -c 16 "$tmp/asset.bin" | od -An -c | tr -s ' '))" ;;
esac

mv -- "$tmp/asset.bin" "$out"
printf 'fetch-model: saved asset %s -> %s (%s bytes)\n' "$asset_id" "$out" "$(wc -c <"$out" | tr -d ' ')"
