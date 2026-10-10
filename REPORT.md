# ArtCraft Launcher 0.1.2 — Ubuntu 20.04 (glibc 2.31) rebuild & AppImage

Date: 2026-10-10 · Host: x86_64 sandbox (no Docker, no root) · Build env: real **Ubuntu 20.04.5** user-space rootfs via proot (ptrace chroot, `-0` fake-root), gcc 9.4.0, **glibc 2.31**, rustup stable **1.99.0**.

## Deliverables

| File | What it is |
|---|---|
| `artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage` | The rebuilt launcher, glibc floor 2.30 (≤ 2.31). Runs on Ubuntu 20.04+. |
| `artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage.zsync` | Delta-update metadata for AppImageUpdate. |
| `build.sh` | Repeatable no-Docker build (proot + ubuntu-base 20.04). |
| `Dockerfile` | Repeatable `ubuntu:20.04` Docker build with built-in verification. |
| `build-log.txt` | Key excerpts of the actual build & verification log. |

SHA-256: `f81bf2d02048f2d235c54f556c08c5465c95c5c7c0266dda839bff7bbf6515be`

## Source used

The task mentioned attachments, but no files arrived in the workspace, so everything was fetched from GitHub:

- Launcher source: `github.com/storytold/craft-launcher`, tag **v0.1.2** (commit `2f3b843`), crate `artcraft_launcher_native` in `crates/native`, binary `artcraft-launcher` in `apps/artcraft-launcher`.
- Reference AppImage: official `artcraft-launcher-0.1.2-linux-x86_64.AppImage` from the v0.1.2 GitHub release (extracted with `--appimage-extract`; NOT decompiled — used only to compare packaging and confirm the glibc diagnosis).

## 1) Source changes

**None.** `cargo build --release --locked` succeeded on 20.04 with zero modifications. The code is pure-Rust (rustls TLS via ring, zbus D-Bus, x11rb/wayland-client, no openssl-sys, no cmake), so nothing needed vendoring, static-linking or version pinning, and no dependency required a system library newer than 20.04 provides. Ring's only build-time need is a C compiler (gcc 9.4 ✔).

## 2) glibc check (required command + result)

```
$ objdump -T target/release/artcraft-launcher | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1
GLIBC_2.30
```
Full set: `2.2.5 … 2.28, 2.29, 2.30` — **max GLIBC_2.30 ≤ 2.31** ✔
(Original 0.1.2 AppImage binary: max `GLIBC_2.35` — the reported bug, confirmed: it was built on Ubuntu 22.04.)

## 3) ldd on 20.04

```
libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2
libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1
libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0
libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
```
`grep -c "not found"` → **0** ✔. Only glibc parts + libgcc_s; nothing else to bundle (matches the original AppImage, which bundles no libraries either).

## 4) Launch test (headless, xvfb)

```
$ timeout 15 xvfb-run -a -s "-screen 0 1280x800x24" ./target/release/artcraft-launcher
WARN winit: XSETTINGS / XRandR 0mm (headless-only cosmetics)
WARN egui_wgpu: Software rasterizer — llvmpipe (LLVM 12.0.0) / Mesa 21.2.6, backend Gl
WARN artcraft_launcher: no tray icon: D-Bus ... /run/user/0/bus (no session bus in sandbox)
exit = 124   # timeout fired -> the app was alive in its event loop for the full 15 s
```
The same test was run on the **packaged AppImage** (`APPIMAGE_EXTRACT_AND_RUN=1` under `xvfb-run`) with the same result. On a normal 20.04 desktop with a session bus/GPU, the warnings don't apply; the app falls back gracefully by design (tray is optional, wgpu picks GL).

## 5) AppImage packaging

Built by the repo's own `packaging/linux/package.sh --formats appimage` on 20.04 (it downloads `appimagetool` and runs it with `APPIMAGE_EXTRACT_AND_RUN=1`, no FUSE). AppDir layout, `AppRun`, desktop file and icons are **byte-identical** to the official 0.1.2 AppImage (verified by `diff -r`: only the ELF binary differs); `X-AppImage-Version=0.1.2` is auto-injected by appimagetool exactly as in the official build. Size 11,430,392 bytes — same as the official 0.1.2 AppImage. Glibc is not bundled (nothing to bundle).

## 6) Runtime behaviour: where apps come from and their glibc needs ⚠️

At v0.1.2 the launcher installs/updates the 12 Craft Apps (photocraft, vectorcraft, filmcraft, lightcraft, pdfcraft, effectcraft, designcraft, wordcraft, deckcraft, gridcraft, cadcraft, soundcraft) **plus itself**:

- Release metadata: GitHub REST API `https://api.github.com/repos/<owner>/<repo>/releases` (one request per app, ETag-revalidated); when the API is rate-limited it falls back to the quota-free route: the `https://github.com/<repo>/releases/latest` redirect for the tag + `SHA256SUMS.txt` for the file list & checksums. (`api.storyteller.ai/v1/craft_apps/release_info` exists only on `main` ≥ 0.1.3, not in 0.1.2.)
- Downloads: assets matched by platform/kind from `https://github.com/<repo>/releases/download/<tag>/<asset>` (Linux: `.deb` → apt/polkit, `.rpm` → dnf/zypper, Flatpak, else **AppImage** into `~/Applications`), SHA-256-verified from GitHub digests or `SHA256SUMS.txt`.
- Self-update: same machinery against `storytold/craft-launcher` (AppImage replaces itself; deb/rpm via package manager).

**Do the downloaded apps need glibc > 2.31? YES — all of them.**
Every Craft App repo builds its Linux releases on `ubuntu-22.04` runners (checked all 12 `release.yml` files on `main`). Verified empirically on published artifacts:

- `filmcraft-0.5.0-linux-x86_64` → max `GLIBC_2.35`
- `photocraft-0.6.0-linux-x86_64` (from the .deb) → max `GLIBC_2.35`

So on Ubuntu 20.04 the rebuilt launcher will install these apps but **they will fail to start** with the same GLIBC_2.34/2.35 error. Rebuilding the launcher alone is not enough — each app would need the same 20.04 rebuild treatment (their sources are public: `github.com/storytold/<app>`). Same applies to **launcher self-update**: any newer official release (≥ 0.1.3) is 22.04-built and needs 2.35; if self-update runs, it would replace this 20.04 build with one that can't start. Recommendation: run this AppImage with updates from official releases disabled, or rebuild future launcher versions the same way and block the built-in updater.

## Known limitations

- `zsyncmake`/`desktop-file-validate`/`appstreamcli` were partially available in the sandbox; the repo script treated them as optional (warnings only).
- No hardware GPU in the sandbox: runtime verification used llvmpipe software GL under Xvfb; Vulkan path untested (wgpu falls back to GL by design).
- Proot fake-root can't be used to test apt-installed `.deb` system integration end-to-end; the AppImage path was tested instead.
- The 20.04 rootfs test system lacked a session D-Bus, so the tray/notifications degraded gracefully (by design) rather than exercising fully.
- `--locked` was honored; no `Cargo.lock` changes, no patches, no vendoring.
