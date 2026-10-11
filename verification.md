# Verification — Craft App Suite rebuilt for Ubuntu 20.04 (glibc 2.31)

All builds ran on a genuine Ubuntu 20.04.5 (glibc 2.31-0ubuntu9.9) user-space rootfs,
rustc 1.99.0 / cargo 1.99.0, `cargo build --release --locked` at the pinned upstream tag,
packaged with each repo's own `packaging/linux/package.sh --formats appimage`.
Every check below ran inside the 20.04 environment; a build is only released if all checks pass.

Build host: sandbox proot rootfs (ubuntu-base 20.04.5), no Docker/root, equivalent to a `container: ubuntu:20.04` CI job; per-app logs kept in the build workspace.

| app | version | upstream tag | max GLIBC | max GLIBCXX | ldd | smoke test | SHA256 | status |
|---|---|---|---|---|---|---|---|---|
| artcraft-launcher | 0.2.0 | v0.2.0 | 2.30 | — | pass | GUI alive after 8s under xvfb | `8fd30e13ea45bc111a95050f843645559f74f2ede48a37d04764e43f2402a21a` | PASS |
| photocraft | 0.7.0 | v0.7.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `34dc025c7b3acbf6ca0d9308b4aab5ca6e9a660ee0db206c9519675642e3ef6a` | PASS |
| vectorcraft | 0.9.0 | v0.9.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `5410508cd551f769b9b5433fff702c09d2b9f42ddc4e5f478546041f1dbb5504` | PASS |
| filmcraft | 0.6.0 | v0.6.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `c25ac9cc085fc16690102fe4cfb4a3f17598d2d0a6e0916d235b628be808e41b` | PASS |
| lightcraft | 0.6.0 | v0.6.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `721b74ec7625b02d835ba5f481324eb150d2cc46570cdfb5c8fef37195abaa48` | PASS |
| pdfcraft | 0.6.0 | v0.6.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `d5db2270d0fbbc39ded5c11ace5f6ffb559e33062e0c245f9d719a5bc71c797a` | PASS |
| effectcraft | 0.8.0 | v0.8.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `768baa8c97d3ba274a3379cb90240460c615916af852425d4f0224b604845269` | PASS |
| designcraft | 0.6.0 | v0.6.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `01236e5967c7bc1c0450c330d90f4e60e11fec5e5bda3401b3abcac927b523da` | PASS |
| wordcraft | 0.5.0 | v0.5.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `109173802f2b75769c35c041e4235c19599c795fb78350f670a0f6def14294f7` | PASS |
| deckcraft | 0.5.0 | v0.5.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `642206812a80bb4c77f525493ef4223f58a17cec3366a7b52374262a5d5b3e4b` | PASS |
| gridcraft | 0.5.0 | v0.5.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `ea3cde22e3eac960b1308128df7b1909f15b4cd61f5dd2cb7121ee58f0156fb4` | PASS |
| cadcraft | 0.5.0 | v0.5.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `0ec02659d24f8038582304ae3aec095c49de117d4b29ee4963f0966e1d081bad` | PASS |
| soundcraft | 0.5.0 | v0.5.0 | 2.30 | — | pass | CLI --version exit 0; GUI alive after 8s under xvfb | `d0a57a7052c3fe0c36cea6bc4ded1476c94dbe5ee975182597272587b8249750` | PASS |

Checks performed for every AppImage:
1. `--appimage-extract`, then `objdump -T` over every ELF file; highest glibc symbol must be ≤ 2.31
   (GLIBCXX ≤ 3.4.28 when present). Result: GLIBC_2.30 everywhere — no GLIBCXX at all (pure Rust).
2. `ldd` on the main binaries: no "not found".
3. Smoke tests: CLI `--version` exit 0; GUI kept alive ~8 s under `xvfb-run` in the 20.04 rootfs
   (llvmpipe software GL; wgpu/eframe start fine — at runtime prefer real GL/Vulkan, see README).
4. SHA256 recorded above and shipped as `SHA256SUMS`.

Note: official upstream AppImages are built on Ubuntu 22.04 and top out at GLIBC_2.35; these
rebuilds top out at GLIBC_2.30, which is why they run on 20.04.
