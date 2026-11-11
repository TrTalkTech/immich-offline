# Upstream touch points

Every Immich file we patch. Keep this list short.

| File | Why | Merge risk |
|------|-----|------------|
| `mobile/android/app/build.gradle` | `applicationId` `app.alextran.immich.offline` | Low |
| `mobile/android/app/src/main/AndroidManifest.xml` | Launcher `Immich Offline`, OAuth `app.immich.offline` | Low |
| `mobile/android/app/src/debug/AndroidManifest.xml` | Debug launcher name | Low |
| `mobile/lib/services/oauth.service.dart` | OAuth callback scheme | Low |
| `mobile/lib/main.dart` | Prefetch on open / resume | Medium |
| `mobile/lib/pages/common/settings.page.dart` | Gallery offline settings entry | Medium |
| `mobile/lib/presentation/pages/search/search.page.dart` | Pinned quick link under Favorites | Medium |
| `mobile/lib/presentation/pages/library.page.dart` | Two-up collection cards | Low |
| `mobile/lib/services/download.service.dart` | Pass capture date/GPS into gallery save | Medium |
| `mobile/lib/repositories/file_media.repository.dart` | saveImageWithFile creationDate/GPS | Low |
| `mobile/lib/repositories/download.repository.dart` | waitForTasks after enqueue | Low |
| `mobile/lib/domain/services/hash.service.dart` | Hash DCIM/Immich album so locals merge with remote | Medium |
| `mobile/lib/presentation/widgets/bottom_sheet/general_bottom_sheet.widget.dart` | Pin action | Medium |
| `mobile/lib/presentation/widgets/bottom_sheet/favorite_bottom_sheet.widget.dart` | Pin action | Medium |
| `mobile/lib/presentation/widgets/bottom_sheet/remote_album_bottom_sheet.widget.dart` | Pin action | Medium |
| `mobile/lib/presentation/widgets/bottom_sheet/archive_bottom_sheet.widget.dart` | Pin action | Medium |

## Marker format

```dart
// FORK(gallery-offline): begin
...minimal glue...
// FORK(gallery-offline): end
```

## Non-touch (owned by fork)

- `mobile/lib/fork/gallery_offline/**`
- `docs/fork/**`
