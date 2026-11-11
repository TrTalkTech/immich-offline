# Upstream-safe fork strategy

**Pinned Immich:** `v3.4.0`  
**Branch:** `feature/gallery-offline`  
**Remote:** `upstream` → `https://github.com/immich-app/immich.git`

## Goal

Gallery offline + pin survive Immich app updates with **minimal manual merge work**.

## Rules

1. **All new code lives under** `mobile/lib/fork/gallery_offline/`.
2. **Do not** add keys to Immich `SettingsKey`, `StoreKey`, or Drift schema for fork features.
3. **Do not** change `auto_route` generated files for fork screens — use `Navigator.push`.
4. Upstream touch points must be few, marked `// FORK(gallery-offline): begin|end`, listed in `TOUCHPOINTS.md`.
5. Persist fork state via `path_provider` JSON (`fork_gallery_offline/`), not Immich Store.
6. Downloads go through Immich `DownloadRepository.downloadAllAssets` → device gallery.
7. When merging upstream: merge tag → fix only TOUCHPOINTS files → leave `mobile/lib/fork/` as-is.
