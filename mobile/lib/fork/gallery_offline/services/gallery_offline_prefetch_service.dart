import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/local_album.service.dart';
import 'package:immich_mobile/extensions/network_capability_extensions.dart';
import 'package:immich_mobile/fork/gallery_offline/gallery_offline_albums.dart';
import 'package:immich_mobile/fork/gallery_offline/gallery_offline_limit.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_entry.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_prefetch_progress.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_scope_target.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_scope_resolver.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_store.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/infrastructure/repositories/remote_asset.repository.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/repositories/download.repository.dart';

typedef PrefetchProgressListener = void Function(GalleryOfflinePrefetchProgress progress);

/// Prefetches originals into the device gallery via Immich's download path.
class GalleryOfflinePrefetchService {
  GalleryOfflinePrefetchService({
    required GalleryOfflineScopeResolver scopeResolver,
    required GalleryOfflineStore store,
    required RemoteAssetRepository remoteAssets,
    required DownloadRepository downloads,
    required BackgroundSyncManager backgroundSync,
    required ConnectivityApi connectivityApi,
    required LocalAlbumService localAlbums,
    this.batchSize = 3,
  }) : _scopeResolver = scopeResolver,
       _store = store,
       _remoteAssets = remoteAssets,
       _downloads = downloads,
       _backgroundSync = backgroundSync,
       _connectivityApi = connectivityApi,
       _localAlbums = localAlbums;

  final GalleryOfflineScopeResolver _scopeResolver;
  final GalleryOfflineStore _store;
  final RemoteAssetRepository _remoteAssets;
  final DownloadRepository _downloads;
  final BackgroundSyncManager _backgroundSync;
  final ConnectivityApi _connectivityApi;
  final LocalAlbumService _localAlbums;
  final int batchSize;

  bool _pauseRequested = false;
  bool _running = false;

  bool get isRunning => _running;

  void pause() {
    _pauseRequested = true;
  }

  Future<GalleryOfflinePrefetchProgress> run({
    required GalleryOfflinePolicy policy,
    required String userId,
    PrefetchProgressListener? onProgress,
  }) async {
    if (_running) {
      return const GalleryOfflinePrefetchProgress(
        status: GalleryOfflinePrefetchStatus.running,
        message: 'Prefetch already running',
      );
    }

    if (!policy.enabled) {
      return const GalleryOfflinePrefetchProgress(
        status: GalleryOfflinePrefetchStatus.idle,
        message: 'Gallery offline is disabled',
      );
    }

    _running = true;
    _pauseRequested = false;

    try {
      await _excludeImmichAlbumFromBackup();
      if (!await _wifiAllowed(policy)) {
        const blocked = GalleryOfflinePrefetchProgress(
          status: GalleryOfflinePrefetchStatus.wifiBlocked,
          message: 'Waiting for Wi‑Fi (unmetered network)',
        );
        onProgress?.call(blocked);
        return blocked;
      }

      final pinnedIds = await _store.loadPinnedIds();
      final targets = await _scopeResolver.resolve(userId: userId, policy: policy, pinnedIds: pinnedIds);
      if (targets.isEmpty) {
        const empty = GalleryOfflinePrefetchProgress(
          status: GalleryOfflinePrefetchStatus.completed,
          message: 'Nothing selected to download',
        );
        onProgress?.call(empty);
        return empty;
      }

      final index = await _store.loadIndex();
      final pending = <GalleryOfflineScopeTarget>[];
      var skipped = 0;
      for (final target in targets) {
        final existing = index[target.assetId];
        // Skip anything already completed. Retrying without a localId created
        // duplicate DCIM/Immich files and made backup treat them as new uploads.
        if (existing != null) {
          skipped++;
        } else {
          pending.add(target);
        }
      }

      var progress = GalleryOfflinePrefetchProgress(
        status: GalleryOfflinePrefetchStatus.running,
        total: targets.length,
        skipped: skipped,
        message: skipped == 0 ? null : 'Resuming · $skipped already in gallery index',
      );
      onProgress?.call(progress);

      if (pending.isEmpty) {
        progress = progress.copyWith(status: GalleryOfflinePrefetchStatus.completed, message: 'Done');
        onProgress?.call(progress);
        return progress;
      }

      for (var i = 0; i < pending.length; i += batchSize) {
        if (_pauseRequested) {
          progress = progress.copyWith(status: GalleryOfflinePrefetchStatus.paused, message: 'Paused');
          onProgress?.call(progress);
          return progress;
        }
        if (!await _wifiAllowed(policy)) {
          progress = progress.copyWith(
            status: GalleryOfflinePrefetchStatus.wifiBlocked,
            message: 'Waiting for Wi‑Fi (unmetered network)',
          );
          onProgress?.call(progress);
          return progress;
        }

        final stats = await _store.stats();
        final chunk = pending.sublist(i, i + batchSize > pending.length ? pending.length : i + batchSize);
        final assets = <RemoteAsset>[];
        final meta = <String, GalleryOfflineScopeTarget>{};
        var usedBytes = stats.usedBytes;
        var hitLimit = usedBytes >= policy.limitBytes;

        for (final target in chunk) {
          final protected = target.protected || pinnedIds.contains(target.assetId);
          if (shouldSkipForStorageLimit(
            protected: protected,
            usedBytes: usedBytes,
            estimatedBytes: target.estimatedBytes,
            limitBytes: policy.limitBytes,
          )) {
            hitLimit = true;
            continue;
          }
          final asset = await _remoteAssets.get(target.assetId);
          if (asset == null) {
            progress = progress.copyWith(failed: progress.failed + 1);
            continue;
          }
          if (!asset.isRemoteOnly) {
            await _store.upsertEntry(
              GalleryOfflineEntry(
                assetId: target.assetId,
                pinned: protected,
                downloadedAt: DateTime.now().toUtc(),
                estimatedBytes: target.estimatedBytes,
                localId: asset.localId,
              ),
            );
            usedBytes += projectedAddBytes(target.estimatedBytes);
            progress = progress.copyWith(skipped: progress.skipped + 1);
            continue;
          }
          assets.add(asset);
          meta[asset.id] = target;
          usedBytes += projectedAddBytes(target.estimatedBytes);
        }

        if (assets.isEmpty) {
          if (hitLimit && !_remainingHasProtected(pending, i + chunk.length, pinnedIds)) {
            progress = progress.copyWith(
              status: GalleryOfflinePrefetchStatus.completed,
              message: 'Storage limit reached',
            );
            onProgress?.call(progress);
            return progress;
          }
          onProgress?.call(progress);
          continue;
        }

        try {
          await _downloads.downloadAllAssets(assets);
          final statuses = await _downloads.waitForTasks(
            assets.map((a) => a.id),
            shouldAbort: () => _pauseRequested,
          );
          // Let DownloadService finish MediaStore save; abort early on Pause.
          final pausedDuringSave = await _waitOrPaused(const Duration(seconds: 2));

          final succeeded = <RemoteAsset>[];
          for (final asset in assets) {
            final status = statuses[asset.id];
            if (status != TaskStatus.complete) {
              progress = progress.copyWith(failed: progress.failed + 1);
              continue;
            }
            succeeded.add(asset);
            final target = meta[asset.id]!;
            await _store.upsertEntry(
              GalleryOfflineEntry(
                assetId: asset.id,
                pinned: target.protected || pinnedIds.contains(asset.id),
                downloadedAt: DateTime.now().toUtc(),
                estimatedBytes: target.estimatedBytes,
              ),
            );
            progress = progress.copyWith(completed: progress.completed + 1);
          }

          if (succeeded.isNotEmpty) {
            await _backgroundSync.syncLocal();
            await _excludeImmichAlbumFromBackup();
            await _backgroundSync.hashAssets();
            await _refreshLocalIds(succeeded.map((a) => a.id));
          }

          if (pausedDuringSave || _pauseRequested) {
            progress = progress.copyWith(status: GalleryOfflinePrefetchStatus.paused, message: 'Paused');
            onProgress?.call(progress);
            return progress;
          }
        } catch (_) {
          progress = progress.copyWith(failed: progress.failed + assets.length);
        }

        onProgress?.call(progress);
      }

      progress = progress.copyWith(
        status: _pauseRequested ? GalleryOfflinePrefetchStatus.paused : GalleryOfflinePrefetchStatus.completed,
        message: _pauseRequested ? 'Paused' : 'Done',
      );
      onProgress?.call(progress);
      return progress;
    } catch (error) {
      final failed = GalleryOfflinePrefetchProgress(
        status: GalleryOfflinePrefetchStatus.error,
        message: error.toString(),
      );
      onProgress?.call(failed);
      return failed;
    } finally {
      _running = false;
    }
  }

  /// Download specific assets into the gallery and mark them pinned.
  Future<void> downloadAndPin(List<RemoteAsset> assets) async {
    if (assets.isEmpty) {
      return;
    }
    final pinned = await _store.loadPinnedIds();
    pinned.addAll(assets.map((a) => a.id));
    await _store.savePinnedIds(pinned);

    final index = await _store.loadIndex();
    final remoteOnly = assets.where((a) => a.isRemoteOnly && !index.containsKey(a.id)).toList();
    for (final asset in assets.where((a) => !a.isRemoteOnly || index.containsKey(a.id))) {
      final existing = index[asset.id];
      await _store.upsertEntry(
        GalleryOfflineEntry(
          assetId: asset.id,
          pinned: true,
          downloadedAt: existing?.downloadedAt ?? DateTime.now().toUtc(),
          estimatedBytes: existing?.estimatedBytes ?? 0,
          localId: asset.localId ?? existing?.localId,
        ),
      );
    }

    if (remoteOnly.isNotEmpty) {
      await _downloads.downloadAllAssets(remoteOnly);
      final statuses = await _downloads.waitForTasks(remoteOnly.map((a) => a.id));
      await Future<void>.delayed(const Duration(seconds: 2));
      final succeeded = <RemoteAsset>[];
      for (final asset in remoteOnly) {
        if (statuses[asset.id] != TaskStatus.complete) {
          continue;
        }
        succeeded.add(asset);
        await _store.upsertEntry(
          GalleryOfflineEntry(assetId: asset.id, pinned: true, downloadedAt: DateTime.now().toUtc()),
        );
      }
      if (succeeded.isNotEmpty) {
        await _backgroundSync.syncLocal();
        await _excludeImmichAlbumFromBackup();
        await _backgroundSync.hashAssets();
        await _refreshLocalIds(succeeded.map((a) => a.id));
      }
    }
  }

  Future<void> unpin(Iterable<String> assetIds) async {
    final pinned = await _store.loadPinnedIds();
    pinned.removeAll(assetIds);
    await _store.savePinnedIds(pinned);

    final index = await _store.loadIndex();
    var changed = false;
    for (final id in assetIds) {
      final entry = index[id];
      if (entry != null && entry.pinned) {
        index[id] = entry.copyWith(pinned: false);
        changed = true;
      }
    }
    if (changed) {
      await _store.saveIndex(index);
    }
  }

  Future<void> _refreshLocalIds(Iterable<String> assetIds) async {
    final index = await _store.loadIndex();
    var changed = false;
    for (final id in assetIds) {
      final entry = index[id];
      if (entry == null) {
        continue;
      }
      final asset = await _remoteAssets.get(id);
      final localId = asset?.localId;
      if (localId != null && localId != entry.localId) {
        index[id] = entry.copyWith(localId: localId);
        changed = true;
      }
    }
    if (changed) {
      await _store.saveIndex(index);
    }
  }

  bool _remainingHasProtected(
    List<GalleryOfflineScopeTarget> pending,
    int start,
    Set<String> pinnedIds,
  ) {
    for (var i = start; i < pending.length; i++) {
      final target = pending[i];
      if (target.protected || pinnedIds.contains(target.assetId)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _waitOrPaused(Duration duration) async {
    const step = Duration(milliseconds: 250);
    var left = duration;
    while (left > Duration.zero) {
      if (_pauseRequested) {
        return true;
      }
      final slice = left < step ? left : step;
      await Future<void>.delayed(slice);
      left -= slice;
    }
    return _pauseRequested;
  }

  Future<bool> _wifiAllowed(GalleryOfflinePolicy policy) async {
    if (!policy.wifiOnly) {
      return true;
    }
    final caps = await _connectivityApi.getCapabilities();
    return caps.isUnmetered;
  }

  /// Downloaded originals live in DCIM/Immich. Exclude that album from backup
  /// so the phone does not upload copies back as new assets.
  Future<void> _excludeImmichAlbumFromBackup() async {
    final albums = await _localAlbums.getAll();
    for (final album in albums) {
      if (!isGalleryOfflineLocalAlbum(album)) {
        continue;
      }
      if (album.backupSelection == BackupSelection.excluded) {
        continue;
      }
      await _localAlbums.update(album.copyWith(backupSelection: BackupSelection.excluded));
    }
  }
}
