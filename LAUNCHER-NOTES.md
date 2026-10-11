# LAUNCHER-NOTES — making the ArtCraft Launcher use these rebuilt AppImages

Everything below is read from the launcher's actual source
(`storytold/craft-launcher` v0.2.0, pinned commit `bd1182e7…`): `crates/core/src/catalog.rs`,
`crates/core/src/platform.rs`, `crates/native/src/source.rs`, `install.rs`, `detect.rs`,
`self_update.rs`, `paths.rs`, and `crates/ui-egui/src/settings.rs`.

## How the launcher finds releases

- The app list and each app's GitHub repo are **hard-coded** in the built-in catalog
  (`const SUITE` in `crates/core/src/catalog.rs`): `photocraft → storytold/photocraft`,
  `filmcraft → storytold/filmcraft`, … plus the launcher itself
  (`artcraft-launcher → storytold/craft-launcher`). **There is no setting to point it at
  another repo** (e.g. these rebuilds). A later version may fetch the list from an API,
  but v0.2.0 does not.
- For each app it asks `https://api.github.com/repos/<repo>/releases/latest`
  (ETag-cached in `~/.local/share/artcraft-launcher/release-cache.json`); if the API
  quota is exhausted it falls back to the `github.com/<repo>/releases/latest` redirect
  plus that release's `SHA256SUMS.txt`.
- The **"Show pre-releases" setting defaults to off** (`prereleases: false` in
  `settings.rs`). With it off, releases marked *pre-release* on GitHub are never offered.

## Where apps live and how they are detected

- Launcher-installed AppImages are copied to `~/Applications/<asset file name>` (mode 755);
  what the launcher installed is tracked in `~/.local/share/artcraft-launcher/installed.json`.
- Detection additionally scans `~/Applications` for any file whose name parses as
  `<app-id>-<semver>-<os>-<arch>.AppImage` (**lowercase app id, case-sensitive**,
  `parse_asset_name` in `platform.rs`). The **version is parsed from the file name**.
- Installing/updating is always an explicit button click. **Nothing is ever
  auto-installed or auto-updated silently.**

## How to make the launcher use these rebuilt AppImages

1. Create `~/Applications` if needed.
2. Copy each rebuilt AppImage in with the **stock file name** shipped here:
   `photocraft-0.7.0-ubuntu20.04-x86_64.AppImage`, `filmcraft-0.6.0-ubuntu20.04-x86_64.AppImage`, …
3. `chmod +x ~/Applications/*.AppImage`.
4. (Re)start the launcher. Each app shows as installed with version **exactly the
   upstream version** (the `-ubuntu20.04-x86_64` tail parses as the asset's os/arch
   tokens, so `filmcraft-0.6.0-ubuntu20.04-x86_64` yields version `0.6.0`). Since the
   upstream `releases/latest` for every app is the same version right now, the launcher
   shows them as **up to date and offers no update** — which is what you want, because
   an "update" would install upstream's glibc-2.35 build.

## How to stop it from updating over these builds

- **Never click *Install* / *Update* for a Craft App in the launcher** while you are on
  Ubuntu 20.04: those buttons always download from the upstream `storytold/*` repos
  (built on 22.04, GLIBC_2.35 — they will not start). The rebuilt AppImages live only
  in `PSNarayananmc/*` repos, which stock launcher v0.2.0 never queries.
- **Keep the "Show pre-releases" setting off** (default). If it is ever turned on and a
  *pre-release* appears upstream, the launcher would offer it — still only on a click.
- **Do not append `-rN` to the file names** if you can avoid it:
  `filmcraft-0.6.0-ubuntu20.04-r2-x86_64.AppImage` parses as semver
  `0.6.0-ubuntu20.04-r2`, a *pre-release* of `0.6.0`, so the launcher would consider
  upstream `0.6.0` newer and show an update button. (Current releases needed no
  suffix — the tags were free.) If a future re-publish must use `-rN`, either accept
  the harmless prompt or rename the file to drop the suffix.
- **Launcher self-update:** the launcher treats itself like any app and can replace its
  own AppImage from `storytold/craft-launcher` releases when one is newer than the
  running copy. This rebuild is exactly upstream's latest (0.2.0), so there is no
  prompt today. When upstream ships 0.3.0 the launcher will offer it — **don't accept
  on Ubuntu 20.04** (that build needs glibc 2.35); keep using this rebuild and watch
  this repo for a 0.3.0 rebuild instead.

## Removing

The launcher's *Remove* works normally on apps it detects in `~/Applications`
(it deletes the AppImage and its self-created menu entry). Or just delete the files.

## One-line launcher run

```sh
chmod +x artcraft-launcher-0.2.0-ubuntu20.04-x86_64.AppImage && ./artcraft-launcher-0.2.0-ubuntu20.04-x86_64.AppImage
```
