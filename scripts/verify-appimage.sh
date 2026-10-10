#!/usr/bin/env bash
# verify-appimage.sh -- Phase 2 verification for one rebuilt Craft App AppImage.
# Runs INSIDE the ubuntu:20.04 build container. The job must FAIL if a check fails.
#
# Usage: verify-appimage.sh <app-id> <upstream-src-dir>
# Env overrides: GUI_BIN, CLI_BIN (defaults: <id>, <id>-cli)
# Writes: verify/<id>.result.json  (machine result, used by the release job)
#         verify/<id>.verify.log   (human-readable evidence)
set -uo pipefail

ID="${1:?usage: verify-appimage.sh <app-id> <upstream-src-dir>}"
SRC="${2:?usage: verify-appimage.sh <app-id> <upstream-src-dir>}"
DIST="$SRC/dist/release"
GUI="${GUI_BIN:-$ID}"
CLI="${CLI_BIN:-$ID-cli}"

mkdir -p verify
LOG="verify/$ID.verify.log"
: > "$LOG"

fail() { echo "VERIFY-FAIL: $*" | tee -a "$LOG"; exit 1; }

echo "==> [$ID] Phase 2 verification started $(date -u +%FT%TZ)" | tee -a "$LOG"

APPIMAGE="$(ls -1 "$DIST"/*.AppImage 2>/dev/null | head -n1)"
[ -n "$APPIMAGE" ] || fail "no .AppImage found in $DIST"
if [ "$(ls -1 "$DIST"/*.AppImage | wc -l)" != "1" ]; then
  echo "note: multiple AppImages found, verifying the first" | tee -a "$LOG"
fi
echo "appimage: $APPIMAGE" | tee -a "$LOG"

# ---- 1. glibc / GLIBCXX symbol scan --------------------------------------------------------------
echo "==> extracting AppImage" | tee -a "$LOG"
rm -rf squashfs-root
"$APPIMAGE" --appimage-extract >/dev/null 2>>"$LOG" || fail "could not --appimage-extract"

echo "==> scanning glibc symbol versions across all ELF files" | tee -a "$LOG"
: > /tmp/glibc_all.txt
n_elf=0
while IFS= read -r f; do
  if file "$f" | grep -q ELF; then
    n_elf=$((n_elf+1))
    objdump -T "$f" 2>/dev/null | grep -o 'GLIBC[X]*_[0-9.]*' >> /tmp/glibc_all.txt || true
  fi
done < <(find squashfs-root -type f)
[ "$n_elf" -gt 0 ] || fail "no ELF files found inside the AppImage"
sort -uV /tmp/glibc_all.txt -o /tmp/glibc_all.txt
MAX_GLIBC="$(grep '^GLIBC_' /tmp/glibc_all.txt | tail -1 | sed 's/^GLIBC_//')"
MAX_GLIBCXX="$(grep '^GLIBCXX_' /tmp/glibc_all.txt | tail -1 | sed 's/^GLIBCXX_//')"
echo "elf_files=$n_elf max_glibc=${MAX_GLIBC:-none} max_glibcxx=${MAX_GLIBCXX:-none}" | tee -a "$LOG"
echo "highest symbol versions found:" | tee -a "$LOG"
tail -2 /tmp/glibc_all.txt | sed 's/^/  /' | tee -a "$LOG"

python3 - "$MAX_GLIBC" "$MAX_GLIBCXX" <<'PY' >> "$LOG" 2>&1 || fail "glibc/GLIBCXX floor is above Ubuntu 20.04's (glibc 2.31 / GLIBCXX 3.4.28)"
import sys
def key(v): return [int(x) for x in v.split('.')]
def le(a, b): return key(a) <= key(b)
glibc, glibcxx = sys.argv[1], sys.argv[2]
ok = True
if glibc and not le(glibc, "2.31"):
    print(f"glibc {glibc} > 2.31"); ok = False
if glibcxx and not le(glibcxx, "3.4.28"):
    print(f"GLIBCXX {glibcxx} > 3.4.28"); ok = False
print(f"glibc check: {'PASS' if ok else 'FAIL'} (max GLIBC={glibc or 'none'}, max GLIBCXX={glibcxx or 'none'}, target <= 2.31 / 3.4.28)")
sys.exit(0 if ok else 1)
PY

# ---- 2. ldd: no missing libraries ----------------------------------------------------------------
echo "==> ldd check" | tee -a "$LOG"
MAIN_BIN="squashfs-root/usr/bin/$GUI"
[ -f "$MAIN_BIN" ] || MAIN_BIN="$(find squashfs-root -type f -name "$GUI" | head -n1)"
[ -f "$MAIN_BIN" ] || fail "main binary $GUI not found in AppDir"
LDD_OUT="$(ldd "$MAIN_BIN" 2>&1 || true)"
echo "$LDD_OUT" | sed 's/^/  /' >> "$LOG"
if printf '%s' "$LDD_OUT" | grep -q 'not found'; then
  fail "ldd reports missing libraries for $GUI"
fi
if [ -n "$CLI" ] && [ -x "squashfs-root/usr/bin/$CLI" ]; then
  if ldd "squashfs-root/usr/bin/$CLI" 2>&1 | grep -q 'not found'; then
    fail "ldd reports missing libraries for $CLI"
  fi
else
  CLI=""
fi
echo "ldd: PASS (no 'not found'; GUI=$GUI${CLI:+, CLI=$CLI})" | tee -a "$LOG"

# ---- 3. smoke tests ------------------------------------------------------------------------------
echo "==> smoke test" | tee -a "$LOG"
SMOKE="PASS"
SMOKE_DETAIL=""
if [ -n "$CLI" ]; then
  if "squashfs-root/usr/bin/$CLI" --version >/tmp/cli.out 2>&1; then
    SMOKE_DETAIL="CLI --version exit 0"
  elif "squashfs-root/usr/bin/$CLI" --help >/tmp/cli.out 2>&1; then
    SMOKE_DETAIL="CLI --help exit 0"
  else
    SMOKE="FAIL"; SMOKE_DETAIL="CLI --version/--help failed"
    tail -5 /tmp/cli.out | tee -a "$LOG"
    fail "CLI smoke test failed"
  fi
  echo "cli smoke: PASS ($SMOKE_DETAIL)" | tee -a "$LOG"
fi
# GUI: must stay alive ~8s under xvfb (or exit 0 cleanly). exit 124 = still alive at timeout.
export XDG_RUNTIME_DIR="/tmp/xdg"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
set +e
timeout 8 xvfb-run -a -s "-screen 0 1280x800x24" \
  env HOME=/tmp LIBGL_ALWAYS_SOFTWARE=1 "$MAIN_BIN" >/tmp/gui.log 2>&1
GUI_RC=$?
set -e
echo "gui exit code: $GUI_RC" | tee -a "$LOG"
sed 's/^/  gui| /' /tmp/gui.log | tail -25 | tee -a "$LOG"
if grep -qiE 'missing library|error while loading|symbol lookup|GLIBC_[0-9.]+. not found|GLIBCXX' /tmp/gui.log; then
  fail "GUI smoke test shows a loader/library error (see log)"
fi
if [ "$GUI_RC" = "124" ]; then
  SMOKE_DETAIL="$SMOKE_DETAIL; GUI alive after 8s under xvfb"
elif [ "$GUI_RC" = "0" ]; then
  SMOKE_DETAIL="$SMOKE_DETAIL; GUI exited 0 under xvfb"
else
  SMOKE="FAIL"
  fail "GUI smoke test failed (exit $GUI_RC)"
fi
echo "smoke: $SMOKE ($SMOKE_DETAIL)" | tee -a "$LOG"

# ---- 4. SHA256 -----------------------------------------------------------------------------------
SHA="$(sha256sum "$APPIMAGE" | awk '{print $1}')"
SIZE="$(stat -c %s "$APPIMAGE")"
echo "sha256: $SHA" | tee -a "$LOG"
echo "size: $SIZE bytes" | tee -a "$LOG"

# ---- result JSON ---------------------------------------------------------------------------------
jq -n --arg id "$ID" --arg appimage "$(basename "$APPIMAGE")" \
  --arg max_glibc "${MAX_GLIBC:-}" --arg max_glibcxx "${MAX_GLIBCXX:-}" \
  --arg smoke_detail "$SMOKE_DETAIL" --arg sha256 "$SHA" --arg size "$SIZE" \
  --arg version "$(basename "$APPIMAGE" | sed -E "s/^$ID-//; s/-linux-.*//")" \
  --arg elf_files "$n_elf" \
  '{id: $id, appimage: $appimage, version: $version, max_glibc: $max_glibc,
    max_glibcxx: $max_glibcxx, ldd: "pass", smoke: "PASS", smoke_detail: $smoke_detail,
    sha256: $sha256, size_bytes: ($size|tonumber), elf_files: ($elf_files|tonumber),
    status: "PASS"}' > "verify/$ID.result.json"
cat "verify/$ID.result.json" | tee -a "$LOG"
echo "==> [$ID] VERIFICATION PASSED" | tee -a "$LOG"
