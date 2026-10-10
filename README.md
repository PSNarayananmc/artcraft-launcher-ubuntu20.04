# ArtCraft Launcher 0.1.2 — Ubuntu 20.04 (glibc 2.31) rebuild

Rebuild of the **ArtCraft Launcher** (`storytold/craft-launcher`, tag `v0.1.2`, crate
`artcraft_launcher_native`) on a genuine **Ubuntu 20.04.5** environment, so it runs on
glibc **2.31** — fixing the official `artcraft-launcher-0.1.2-linux-x86_64.AppImage`,
which requires GLIBC_2.34/2.35 (it was built on Ubuntu 22.04).

## Download

Grab the AppImage from the repo **Releases** page:
`artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage` (+ `.zsync` for AppImageUpdate delta updates).

```
chmod +x artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage
./artcraft-launcher-0.1.2-ubuntu20.04-x86_64.AppImage
```

SHA-256: `f81bf2d02048f2d235c54f556c08c5465c95c5c7c0266dda839bff7bbf6515be`

## What's in here

| File | Purpose |
|---|---|
| `build.sh` | Repeatable no-Docker build: proot (user-space chroot) + ubuntu-base 20.04 rootfs + rustup + cargo build + AppImage packaging. |
| `Dockerfile` | The same pipeline on a clean `ubuntu:20.04` image, with glibc/ldd/xvfb checks built in. |
| `REPORT.md` | Full report: source changes (none), glibc check output, ldd, launch test, AppImage diff vs official, runtime download analysis. |
| `build-log.txt` | Key excerpts of the actual build & verification log. |

## Rebuild it yourself

```sh
# Docker path
docker build -t ac-launcher-2004 .
docker run --rm -v "$PWD/out:/out" ac-launcher-2004

# or, without Docker/root:
bash build.sh
```

## Key results

- `cargo build --release --locked` — **zero source changes** (all-pure-Rust deps: rustls/ring, zbus, x11rb, wayland-client).
- `objdump -T … | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1` → **GLIBC_2.30** (≤ 2.31).
- `ldd` → no missing libraries (glibc + libgcc_s only; nothing else to bundle).
- Launch test under `xvfb-run` on 20.04 → app runs (wgpu on llvmpipe; tray degrades gracefully without D-Bus).
- AppImage packaged with the repo's own `packaging/linux/package.sh` + `appimagetool` on 20.04; AppDir is byte-identical to the official one except the ELF binary.

## ⚠️ Known limitation (important)

The launcher **downloads** the Craft Apps (photocraft, filmcraft, pdfcraft, …) from
`github.com/storytold/<app>/releases`. **All 12 apps' official Linux releases are built on
ubuntu-22.04 runners and require GLIBC_2.35** (verified on published `filmcraft-0.5.0` and
`photocraft-0.6.0` binaries). On Ubuntu 20.04 the rebuilt launcher will install those apps,
but they will not start until each app is rebuilt the same way. The launcher's built-in
**self-update** would also pull a 2.35 build — keep it pointed at this rebuild or disable it.

Upstream sources: https://github.com/storytold/craft-launcher (MIT OR Apache-2.0).
