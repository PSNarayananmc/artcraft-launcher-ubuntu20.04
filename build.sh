#!/usr/bin/env bash
# build.sh -- Rebuild ArtCraft Launcher 0.1.2 for Ubuntu 20.04 (glibc 2.31) and package an AppImage.
#
# Two supported paths:
#   1) Docker (recommended):     see Dockerfile next to this script
#        docker build -t ac-launcher-2004 .
#        docker run --rm -v "$PWD/out:/out" ac-launcher-2004
#   2) proot (no root / no Docker): THIS script. It builds a real Ubuntu 20.04
#      rootfs (ubuntu-base) and chroots into it as an unprivileged user via proot.
#      Tested on Debian 13 x86_64 with no Docker, no sudo, no unshare.
#
# Output: dist/artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage (+ .zsync)
set -euo pipefail

BASE=/home/z/my-project/work           # scratch space (rootfs, tools, sources)
TOOL="$BASE/tools"
ROOTFS="$BASE/rootfs-2004"
SRC="$BASE/craft-launcher"
PROOT_VER=v5.3.0

mkdir -p "$TOOL" "$BASE"

# ---- 1. proot (user-space chroot; needs no privileges) -----------------------------------------
if [ ! -x "$TOOL/proot" ]; then
  echo "==> downloading proot"
  curl -fsSL -o "$TOOL/proot" "https://github.com/proot-me/proot/releases/download/${PROOT_VER}/proot-v5.3.0-x86_64-static"
  chmod +x "$TOOL/proot"
fi

# ---- 2. Ubuntu 20.04 rootfs -------------------------------------------------------------------
if [ ! -d "$ROOTFS/usr" ]; then
  echo "==> downloading ubuntu-base 20.04.5"
  curl -fsSL -o "$BASE/ubuntu-base.tar.gz" \
    "https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.5-base-amd64.tar.gz"
  mkdir -p "$ROOTFS"
  tar -xzf "$BASE/ubuntu-base.tar.gz" -C "$ROOTFS"
fi

chroot2004() {
  # -0 fakes uid 0 so apt/dpkg behave; binds give network + our workspace
  "$TOOL/proot" -0 \
    -r "$ROOTFS" \
    -b /dev -b /proc -b /sys \
    -b /etc/resolv.conf:/etc/resolv.conf \
    -b /etc/hosts:/etc/hosts \
    -b "$BASE":"$BASE" \
    -w /home/z/my-project/work \
    /usr/bin/env -i HOME=/root TERM="${TERM:-xterm-256color}" \
      PATH=/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      LANG=C.UTF-8 DEBIAN_FRONTEND=noninteractive \
    /bin/bash --login -c "$*"
}

# ---- 3. Build deps from the 20.04 apt repos ---------------------------------------------------
echo "==> apt: build tools + X11/Wayland/xkb dev packages + xvfb"
chroot2004 "apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential pkg-config curl ca-certificates git file xz-utils libssl-dev \
  libxkbcommon-dev libwayland-dev libx11-dev libxcb1-dev \
  xvfb xauth \
  libgl1-mesa-dri libglx-mesa0 libegl-mesa0 libgl1 libegl1 \
  libx11-6 libxcursor1 libxrandr2 libxi6 libxkbcommon-x11-0 libxkbcommon0 \
  libxcb-render0 libxcb-shape0 libxcb-xfixes0"

# ---- 4. Rust via rustup (stable) ---------------------------------------------------------------
chroot2004 "test -x /root/.cargo/bin/cargo || { curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh && sh /tmp/rustup-init.sh -y --default-toolchain stable --profile minimal; }"
chroot2004 "rustc --version && cargo --version && ldd --version | head -1"

# ---- 5. Source ---------------------------------------------------------------------------------
if [ ! -d "$SRC/.git" ]; then
  echo "==> cloning storytold/craft-launcher"
  git clone https://github.com/storytold/craft-launcher.git "$SRC"
fi
git -C "$SRC" fetch --depth 1 origin tag v0.1.2
git -C "$SRC" checkout v0.1.2

# ---- 6. Build -----------------------------------------------------------------------------------
echo "==> cargo build --release --locked"
chroot2004 "cd $SRC && cargo build --release --locked -p artcraft-launcher"

# ---- 7. Verify glibc floor ----------------------------------------------------------------------
echo "==> glibc symbol check"
chroot2004 "objdump -T $SRC/target/release/artcraft-launcher | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1"
# expected: GLIBC_2.30 (must be <= 2.31)

# ---- 8. Smoke test under xvfb (no display needed) ----------------------------------------------
echo "==> xvfb smoke test (15 s run; expect exit 124 with the app still alive)"
chroot2004 "cd $SRC && (timeout 15 xvfb-run -a -s '-screen 0 1280x800x24' ./target/release/artcraft-launcher >/tmp/launch.log 2>&1; echo exit=\$?)"

# ---- 9. Package the AppImage (repo's own packaging script, appimage format only) ---------------
echo "==> packaging AppImage"
chroot2004 "cd $SRC && bash packaging/linux/package.sh --formats appimage"

OUT="$SRC/dist/release/artcraft-launcher-0.1.2-linux-x86_64.AppImage"
DEST="$BASE/../download/artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage"
mkdir -p "$(dirname "$DEST")"
cp "$OUT" "$DEST"
cp "$OUT.zsync" "$DEST.zsync" 2>/dev/null || true
echo "==> wrote $DEST"
sha256sum "$DEST"
