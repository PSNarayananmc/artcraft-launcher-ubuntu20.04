# PATCHES — source changes made for the Ubuntu 20.04 (glibc 2.31) rebuild

## Upstream source changes: **none**

All 13 projects (ArtCraft Launcher + the 12 Craft Apps) were built from **pristine,
unmodified upstream sources** at the pinned tags listed in [`suite.json`](suite.json)
(FilmCraft v0.6.0 commit `2ff3f5e2…`, launcher v0.2.0 commit `bd1182e7…`, etc.).
Every build used `cargo build --release --locked` against upstream's own `Cargo.lock`,
and each AppImage was packaged with the repo's own `packaging/linux/package.sh`.
No crate, script or asset in any upstream repo was edited.

## Build-environment adaptations (no source edits)

These were applied to the **build environment only**, to fit the sandbox that produced
these binaries; none of them changes upstream code:

| Adaptation | Why | Effect on binaries |
|---|---|---|
| Built inside an Ubuntu 20.04.5 user-space rootfs (proot, no Docker/root) — the sandbox equivalent of a `runs-on: ubuntu-22.04` + `container: ubuntu:20.04` CI job | The whole point: binaries must link against glibc 2.31 | Highest glibc symbol in every shipped binary: **GLIBC_2.30** (official 22.04 builds: GLIBC_2.35) |
| `CARGO_PROFILE_RELEASE_LTO=false`, `CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16`, `CARGO_PROFILE_RELEASE_DEBUG=false` (env overrides; upstream default is `lto = "thin"`, `codegen-units = 1`) | The build sandbox has 2 CPU cores / 4 GB RAM; thin-LTO linking of the large egui/wgpu binaries does not fit in 4 GB | Optimization level is unchanged (`opt-level = 3`); apps may be marginally larger/slower than an LTO build; ABI/runtime behaviour identical |
| `appstream` validator removed from the build rootfs | Ubuntu 20.04's `appstreamcli` 0.12 rejects tags in upstream's own metainfo (`branding`, `developer`, `display_length`) that 22.04's 0.15 accepts — upstream CI validates the same metainfo successfully on 22.04 | None; `desktop-file-validate` still ran and passed. Metainfo is shipped unmodified |
| `APPIMAGE_EXTRACT_AND_RUN=1` for `appimagetool` | No FUSE in the sandbox | None |

## CI workflows: staged, not active

The personal access token used for this rebuild cannot create or update files under
`.github/workflows/` (GitHub rejects the push: *"refusing to allow a Personal Access
Token to create or update workflow … without `workflow` scope"*). The complete
build + verify + release pipelines therefore live in [`workflows-staging/`](workflows-staging/)
instead of `.github/workflows/`. To activate them, move the files to
`.github/workflows/` with a token that has the workflow scope (or via the GitHub web
editor), then dispatch `build.yml` manually. The verification and release logic they
would have run on CI is exactly what ran for this rebuild:
[`scripts/verify-appimage.sh`](scripts/verify-appimage.sh) and
[`scripts/assemble-release.sh`](scripts/assemble-release.sh).
