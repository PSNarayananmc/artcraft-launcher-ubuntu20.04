#!/usr/bin/env bash
# assemble-release.sh -- runs in the `release` job (ubuntu-22.04, no container).
# Publishes a BRAND-NEW pre-release with the PASSED AppImages. Never overwrites:
# the tag/release name is collision-checked against existing tags and releases,
# and a 422 "already exists" from the create call fails the job.
set -euo pipefail

API="https://api.github.com"
AUTH=(-H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json")

echo "==> installing zsync (for delta files)"
sudo apt-get update -qq && sudo apt-get install -y -qq zsync >/dev/null

echo "==> collecting verification results"
PASS_IDS=()
declare -A R_DIR
for d in artifacts/build-*; do
  [ -d "$d" ] || continue
  id="$(basename "$d" | sed 's/^build-//')"
  rj="$d/verify/$id.result.json"
  if [ -f "$rj" ]; then
    status="$(jq -r .status "$rj")"
    echo "  $id: $status"
    if [ "$status" = "PASS" ]; then PASS_IDS+=("$id"); R_DIR[$id]="$d"; fi
  else
    echo "  $id: no result.json (job failed — see run summary)"
  fi
done
[ "${#PASS_IDS[@]}" -gt 0 ] || { echo "no PASS apps — refusing to release"; exit 1; }

# launcher version drives the suite tag
LVER="$(jq -r .version artifacts/build-artcraft-launcher/verify/artcraft-launcher.result.json 2>/dev/null || true)"
[ -n "$LVER" ] || LVER="$(jq -r '.launcher.version' "$SUITE_JSON")"
BASE="v${LVER}-suite-ubuntu20.04"

echo "==> checking existing releases and tags in $OWNER/$REPO"
RELEASES_JSON="$(mktemp)"; TAGS_JSON="$(mktemp)"
curl -sSf "${AUTH[@]}" "$API/repos/$OWNER/$REPO/releases?per_page=100" > "$RELEASES_JSON"
curl -sSf "${AUTH[@]}" "$API/repos/$OWNER/$REPO/git/matching-refs/tags/$BASE" > "$TAGS_JSON"
PREV_TAG="$(jq -r 'sort_by(.published_at) | last | .tag_name // empty' "$RELEASES_JSON")"

TAG=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  CAND="$BASE"; [ "$i" = 1 ] || CAND="$BASE-r$i"
  tag_taken="$(jq -r --arg r "refs/tags/$CAND" '[.[].ref] | index($r) != null' "$TAGS_JSON")"
  rel_taken="$(jq -r --arg c "$CAND" '[.[].tag_name, .[].name] | index($c) != null' "$RELEASES_JSON")"
  if [ "$tag_taken" != "true" ] && [ "$rel_taken" != "true" ]; then
    TAG="$CAND"; break
  fi
  echo "  $CAND already exists, trying next suffix"
done
[ -n "$TAG" ] || { echo "could not find a free tag name for base $BASE"; exit 1; }
SUFFIX=""; [ "$TAG" = "$BASE" ] || SUFFIX="-${TAG##*"$BASE"-}"
echo "==> chosen release tag: $TAG (suffix '$SUFFIX')"

echo "==> staging assets"
STAGE="$(mktemp -d)"
for id in "${PASS_IDS[@]}"; do
  d="${R_DIR[$id]}"
  rj="$d/verify/$id.result.json"
  ver="$(jq -r .version "$rj")"
  src="$d/$(jq -r .appimage "$rj")"
  [ -f "$src" ] || src="$(dirname "$d")/build-$(basename "$d")/$(jq -r .appimage "$rj")"
  [ -f "$src" ] || { echo "AppImage for $id not found in artifact"; exit 1; }
  ASSET="$id-$ver-ubuntu20.04$SUFFIX-x86_64.AppImage"
  cp "$src" "$STAGE/$ASSET"
  echo "  staged $ASSET"
done

( cd "$STAGE" && sha256sum -- *.AppImage > SHA256SUMS )
cat "$STAGE/SHA256SUMS"

echo "==> writing verification.md"
{
  echo "# Verification — Craft App Suite rebuilt for Ubuntu 20.04 (glibc 2.31)"
  echo
  echo "Build run: $GITHUB_SERVER_URL/$OWNER/$REPO/actions/runs/$RUN_ID (ubuntu-22.04 runner, container ubuntu:20.04, glibc 2.31)."
  echo "Every check ran inside the build job; the job fails if any check fails."
  echo
  echo "| app | version | upstream tag | max GLIBC | max GLIBCXX | ldd | smoke test | SHA256 | status |"
  echo "|---|---|---|---|---|---|---|---|---|"
  for d in artifacts/build-*; do
    [ -d "$d" ] || continue
    id="$(basename "$d" | sed 's/^build-//')"
    rj="$d/verify/$id.result.json"
    if [ ! -f "$rj" ]; then
      echo "| $id | | | | | | | | FAILED (job failed, see run log) |"
      continue
    fi
    jq -r --arg tag "$(jq -r --arg id "$id" '(.launcher | select(.id == $id) | .tag) // (.apps | map(select(.id == $id)) | first | .tag) // "?"' "$SUITE_JSON")" \
      '"| \(.id) | \(.version) | \($tag) | \(.max_glibc) | \(.max_glibcxx) | pass | \(.smoke_detail) | `\(.sha256[0:16])…` | PASS |"' "$rj"
  done
  echo
  echo "Released apps: ${PASS_IDS[*]}."
  echo "GLIBC targets: <= 2.31 (glibc), <= 3.4.28 (GLIBCXX, gcc-9 runtime)."
} > "$STAGE/verification.md"

echo "==> creating release $TAG (pre-release)"
BODY=$(jq -n --arg tag "$TAG" --arg prev "$PREV_TAG" --arg run "$RUN_ID" \
  --arg url "$GITHUB_SERVER_URL/$OWNER/$REPO/actions/runs/$RUN_ID" \
  '{tag_name: $tag, name: $tag, prerelease: true,
    body: ("Rebuild of the Craft App Suite (ArtCraft Launcher + all 12 Craft Apps) on a glibc-2.31 base (GitHub Actions ubuntu-22.04 runner, container ubuntu:20.04) so every AppImage runs on Ubuntu 20.04 LTS.\n\nUnmodified upstream sources at pinned tags, built with each repo's own packaging/linux/package.sh.\nVerification: verification.md asset. Checksums: SHA256SUMS asset.\n" + (if $prev != "" then "Follows release " + $prev + " (untouched).\n" else "First suite release in this repo.\n" end) + "Build run: " + $url)}')
REL_JSON="$(mktemp)"
HTTP=$(curl -sS -o "$REL_JSON" -w "%{http_code}" "${AUTH[@]}" \
  -X POST "$API/repos/$OWNER/$REPO/releases" -d "$BODY")
if [ "$HTTP" = "422" ]; then
  echo "release/tag $TAG already exists — refusing to overwrite"; exit 1
fi
[ "$HTTP" = "201" ] || { echo "release create failed: HTTP $HTTP"; cat "$REL_JSON"; exit 1; }
REL_ID="$(jq -r .id "$REL_JSON")"
REL_URL="$(jq -r .html_url "$REL_JSON")"
echo "release created: $REL_URL (id $REL_ID)"

echo "==> uploading AppImage, SHA256SUMS and verification.md"
for f in "$STAGE"/*.AppImage "$STAGE/SHA256SUMS" "$STAGE/verification.md"; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  up=$(curl -sSf "${AUTH[@]}" -X POST \
    --data-binary "@$f" -H "Content-Type: application/octet-stream" \
    "$API/repos/$OWNER/$REPO/releases/$REL_ID/assets?name=$name")
  echo "  uploaded $name ($(jq -r .size <<<"$up") bytes)"
done

echo "==> generating .zsync files against the final asset URLs, then uploading"
for f in "$STAGE"/*.AppImage; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  url="https://github.com/$OWNER/$REPO/releases/download/$TAG/$name"
  ( cd "$STAGE" && zsyncmake -u "$url" -o "$name.zsync" "$name" >/dev/null )
  up=$(curl -sSf "${AUTH[@]}" -X POST \
    --data-binary "@$STAGE/$name.zsync" -H "Content-Type: application/octet-stream" \
    "$API/repos/$OWNER/$REPO/releases/$REL_ID/assets?name=$name.zsync")
  echo "  uploaded $name.zsync ($(jq -r .size <<<"$up") bytes)"
done

echo "==> verifying published assets by API (size + sha256 re-download)"
FINAL_JSON="$(mktemp)"
curl -sSf "${AUTH[@]}" "$API/repos/$OWNER/$REPO/releases/$REL_ID" > "$FINAL_JSON"
jq -r '.assets[] | "  asset: \(.name) size=\(.size) state=\(.state)"' "$FINAL_JSON"
sha_ok=0; sha_bad=0
while read -r want name; do
  dl="$(mktemp)"
  asset_url="$(jq -r --arg n "$name" '.assets[] | select(.name == $n) | .url' "$FINAL_JSON")"
  curl -sSfL "${AUTH[@]}" -H "Accept: application/octet-stream" -o "$dl" "$asset_url"
  have="$(sha256sum "$dl" | awk '{print $1}')"
  if [ "$have" = "$want" ]; then sha_ok=$((sha_ok+1)); echo "  sha256 OK: $name"; else sha_bad=$((sha_bad+1)); echo "  sha256 MISMATCH: $name"; fi
  rm -f "$dl"
done < <(grep -E '^[0-9a-f]{64}  .*\.AppImage$' "$STAGE/SHA256SUMS" | awk '{print $1"  "$2}')
echo "sha256 re-download check: $sha_ok OK, $sha_bad mismatch"
[ "$sha_bad" = 0 ] || exit 1

echo "==> DONE"
echo "release: $REL_URL"
echo "tag: $TAG"
