# Craft App Suite — Ubuntu 20.04 (glibc 2.31) rebuilds

Rebuilds of the **ArtCraft Launcher** and **all 12 Craft Apps** so they run on
**Ubuntu 20.04 LTS** (glibc 2.31). The official AppImages are built on Ubuntu 22.04
(glibc 2.35) and fail on 20.04 with `GLIBC_2.3x not found`; every binary here tops out
at **GLIBC_2.30**, verified per app (glibc symbol scan, `ldd`, CLI + GUI smoke tests —
see [`verification.md`](verification.md)).

**Sources are the unmodified upstream repos of the [storytold](https://github.com/storytold)
organization** (the [getartcraft.com](https://getartcraft.com) "Craft App Suite"), built at
pinned tags with each repo's own packaging script. No upstream code was changed —
see [`PATCHES.md`](PATCHES.md). App licences are MIT OR Apache-2.0 (upstream
`LICENSE-APACHE` / `LICENSE-MIT` / `NOTICE` / `ATTRIBUTION.md` are kept in this repo).

## Downloads — one release with everything

**[v0.2.0-suite-ubuntu20.04](https://github.com/PSNarayananmc/artcraft-launcher-ubuntu20.04/releases/tag/v0.2.0-suite-ubuntu20.04)**
(pre-release) — 13 AppImages + `SHA256SUMS` + `verification.md`:

| App | What it is | Version | Upstream | Asset |
|---|---|---|---|---|
| ArtCraft Launcher | Installs, updates and starts the suite | 0.2.0 | [craft-launcher](https://github.com/storytold/craft-launcher) | `artcraft-launcher-0.2.0-ubuntu20.04-x86_64.AppImage` |
| PhotoCraft | Image editing (Photoshop-like) | 0.7.0 | [photocraft](https://github.com/storytold/photocraft) | `photocraft-0.7.0-ubuntu20.04-x86_64.AppImage` |
| VectorCraft | Vector illustration (Illustrator-like) | 0.9.0 | [vectorcraft](https://github.com/storytold/vectorcraft) | `vectorcraft-0.9.0-ubuntu20.04-x86_64.AppImage` |
| FilmCraft | Video editing, color and sound (Premiere-like) | 0.6.0 | [filmcraft](https://github.com/storytold/filmcraft) | `filmcraft-0.6.0-ubuntu20.04-x86_64.AppImage` |
| LightCraft | Photo library and raw development (Lightroom-like) | 0.6.0 | [lightcraft](https://github.com/storytold/lightcraft) | `lightcraft-0.6.0-ubuntu20.04-x86_64.AppImage` |
| PdfCraft | Reading, organizing and protecting PDFs (Acrobat-like) | 0.6.0 | [pdfcraft](https://github.com/storytold/pdfcraft) | `pdfcraft-0.6.0-ubuntu20.04-x86_64.AppImage` |
| EffectCraft | Motion graphics and visual effects (After Effects-like) | 0.8.0 | [effectcraft](https://github.com/storytold/effectcraft) | `effectcraft-0.8.0-ubuntu20.04-x86_64.AppImage` |
| DesignCraft | Page layout and publishing (InDesign-like) | 0.6.0 | [designcraft](https://github.com/storytold/designcraft) | `designcraft-0.6.0-ubuntu20.04-x86_64.AppImage` |
| WordCraft | Writing and document design (Word-like) | 0.5.0 | [wordcraft](https://github.com/storytold/wordcraft) | `wordcraft-0.5.0-ubuntu20.04-x86_64.AppImage` |
| DeckCraft | Presentations and slide shows (PowerPoint-like) | 0.5.0 | [deckcraft](https://github.com/storytold/deckcraft) | `deckcraft-0.5.0-ubuntu20.04-x86_64.AppImage` |
| GridCraft | Spreadsheets and data (Excel-like) | 0.5.0 | [gridcraft](https://github.com/storytold/gridcraft) | `gridcraft-0.5.0-ubuntu20.04-x86_64.AppImage` |
| CADCraft | Computer-aided design and drafting (AutoCAD-like) | 0.5.0 | [cadcraft](https://github.com/storytold/cadcraft) | `cadcraft-0.5.0-ubuntu20.04-x86_64.AppImage` |
| SoundCraft | Recording, editing and mixing audio (Pro Tools-like) | 0.5.0 | [soundcraft](https://github.com/storytold/soundcraft) | `soundcraft-0.5.0-ubuntu20.04-x86_64.AppImage` |

Direct asset URLs look like
`https://github.com/PSNarayananmc/artcraft-launcher-ubuntu20.04/releases/download/v0.2.0-suite-ubuntu20.04/<asset>`.
Each AppImage also ships with a `.zsync` for AppImageUpdate delta updates.

FilmCraft additionally has its own repo and release:
[filmcraft-ubuntu20.04](https://github.com/PSNarayananmc/filmcraft-ubuntu20.04)
([release v0.6.0-ubuntu20.04](https://github.com/PSNarayananmc/filmcraft-ubuntu20.04/releases/tag/v0.6.0-ubuntu20.04))
— byte-identical to the copy here (same SHA256, built once).

## Run (Ubuntu 20.04+)

```sh
chmod +x <app>-<version>-ubuntu20.04-x86_64.AppImage
./<app>-<version>-ubuntu20.04-x86_64.AppImage
```

For example: `chmod +x filmcraft-0.6.0-ubuntu20.04-x86_64.AppImage && ./filmcraft-0.6.0-ubuntu20.04-x86_64.AppImage`.

**Vulkan / OpenGL driver note:** these are GUI apps (egui/eframe, wgpu/glow). On a
desktop session with working 3D acceleration they just run. On machines without a
usable driver install one first:

- NVIDIA: the proprietary driver (`ubuntu-drivers install` or from NVIDIA), which
  provides Vulkan and GL.
- AMD/Intel: Mesa — `sudo apt install mesa-vulkan-drivers libgl1-mesa-dri` on 20.04.

## Using the ArtCraft Launcher with these builds

The launcher hard-codes the upstream `storytold/*` repos for updates, so **install these
AppImages manually** into `~/Applications` (keep the file names) — the launcher then
detects, launches and manages them, and shows them as up to date. Full details,
including how to avoid the (click-only) update prompts that would fetch glibc-2.35
builds: **[`LAUNCHER-NOTES.md`](LAUNCHER-NOTES.md)**.

```sh
mkdir -p ~/Applications
cp *-ubuntu20.04-x86_64.AppImage ~/Applications/
chmod +x ~/Applications/*.AppImage
```

## What this repo contains

| File | Purpose |
|---|---|
| `suite.json` | The full recon: the 12 apps + launcher, pinned upstream tags/commits, build commands |
| `verification.md`, `SHA256SUMS` | Per-app verification table and checksums (same files as release assets) |
| `PATCHES.md` | Source changes: **none**; environment adaptations documented |
| `LAUNCHER-NOTES.md` | How to point the launcher at these builds and keep it from "updating" over them |
| `scripts/` | `verify-appimage.sh` (per-app verification) and `assemble-release.sh` (release assembly) |
| `workflows-staging/` | CI build/verify/release pipelines, ready to move to `.github/workflows/` (see PATCHES.md) |
| `build.sh`, `Dockerfile`, `REPORT.md`, `build-log.txt` | The original **ArtCraft Launcher 0.1.2** rebuild (release [`v0.1.2-ubuntu20.04`](https://github.com/PSNarayananmc/artcraft-launcher-ubuntu20.04/releases/tag/v0.1.2-ubuntu20.04), untouched) |
| `LICENSE-APACHE`, `LICENSE-MIT`, `NOTICE`, `ATTRIBUTION.md` | Upstream launcher licences and asset attribution |

## Licence notes

Unmodified upstream source, built on glibc 2.31; patches (none) listed in
[`PATCHES.md`](PATCHES.md). The Craft Apps and the launcher are MIT OR Apache-2.0;
their licence and attribution files are kept alongside. The ArtCraft name, wordmark and
"A" mark are trademarks of the ArtCraft Team (see upstream `NOTICE` /
`docs/brand/LICENSE-brand.txt`); product names like Photoshop® or Premiere Pro® are
mentioned only to describe what each app replaces — the suite is not affiliated with,
sponsored by or endorsed by Adobe, Microsoft, Autodesk or Avid.

All credit for the software goes to the upstream authors:
https://github.com/storytold — website: https://getartcraft.com
