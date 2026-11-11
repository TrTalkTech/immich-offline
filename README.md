# Immich Offline (Gallery) Fork

Fork of Immich mobile (**v3.4.0**) packaged as a side-by-side Android app **Immich Offline**  
(`applicationId`: `app.alextran.immich.offline`).

Upstream Immich remains installable next to this app. Fork-only code lives under `mobile/lib/fork/gallery_offline/` with a short list of marked touchpoints (see `TOUCHPOINTS.md` / `UPSTREAM.md`).

---

## Features / Функционал

### English

- **Gallery offline** — downloads **originals** into the Android gallery (`DCIM/Immich`) through Immich’s existing download pipeline (not a private app cache).
- **Scope** — recent timeline window (3 / 6 / 12 months), **Favorites**, and selected remote albums.
- **Storage limit** — stop prefetch when used size reaches the chosen cap (256 KB…50 GB presets for testing/real use).
- **Wi‑Fi only** — optional unmetered-only prefetch; clear Waiting for Wi‑Fi status when blocked.
- **Prefetch on open** — optional background download after launch.
- **Pause / Download now / Apply eviction** — control the queue; eviction removes out-of-scope gallery copies while keeping pins and protected album/favorites scope.
- **Pin (Android)** — pin/unpin from the asset action sheet; pinned items download to the gallery and are protected from auto-eviction. List: **Search → Pinned**.
- **No re-upload loop** — the `DCIM/Immich` album is auto-excluded from backup; hashing still runs so timeline assets merge with local originals.
- **Metadata preserved** — originals keep EXIF dates/GPS (no re-encode).

Does **not** include the old private app-cache offline implementation or the tag shortcut widget.

### Русский

- **Gallery offline** — скачивает **оригиналы** в галерею Android (`DCIM/Immich`) через штатный download Immich (не в приватный кэш приложения).
- **Область** — окно недавних фото (3 / 6 / 12 месяцев), **Избранное** и выбранные удалённые альбомы.
- **Лимит места** — остановка prefetch при достижении лимита (пресеты от 256 KB до 50 GB).
- **Только Wi‑Fi** — опционально только неmetered-сеть; статус Waiting for Wi‑Fi при блокировке.
- **Prefetch при открытии** — фоновая загрузка после запуска.
- **Pause / Download now / Apply eviction** — управление очередью; eviction удаляет копии вне области, сохраняя пины и защищённый scope.
- **Pin (Android)** — закрепить/открепить из action sheet; пин качается в галерею и не вытесняется. Список: **Search → Pinned**.
- **Без повторной загрузки на сервер** — альбом `DCIM/Immich` исключается из backup; hashing всё равно идёт, чтобы ассеты в таймлайне сливались с локальными оригиналами.
- **Метаданные** — EXIF дата/GPS сохраняются (без перекодирования).

Старая offline-реализация в приватном кэше приложения и виджет ярлыка по тегу **не** входят в этот форк.

---

## Version

| Item | Value |
|------|--------|
| Based on Immich | **v3.4.0** |
| App `versionName` | `3.4.0` |
| App `versionCode` | `3040099` |
| Package | `app.alextran.immich.offline` |
| Platform | Android (primary) |

## Build (Android)

Requirements match upstream Immich mobile (Flutter, JDK 21, Android SDK, rustup for `native_core`).

```bash
cd mobile
dart run bin/generate_keys.dart
# open-api dart SDK + pigeon + drift migrations as in Immich docs when needed
flutter build apk --release
```

APK id/name overrides live in `mobile/android/app/build.gradle` (`Immich Offline`).

## Upstream merges

Pin Immich tags in `UPSTREAM.md`. Merge the tag into `feature/gallery-offline`, resolve only files listed in `TOUCHPOINTS.md`, leave `mobile/lib/fork/` intact.
