import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/local_album.service.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_prefetch_progress.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_stats.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_eviction.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_prefetch_service.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_scope_resolver.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_store.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/download.repository.dart';

final galleryOfflineStoreProvider = Provider<GalleryOfflineStore>((ref) {
  return GalleryOfflineStore();
});

final galleryOfflineScopeResolverProvider = Provider<GalleryOfflineScopeResolver>((ref) {
  return GalleryOfflineScopeResolver(ref.watch(driftProvider));
});

final galleryOfflineEvictionProvider = Provider<GalleryOfflineEviction>((ref) {
  return GalleryOfflineEviction(ref.watch(galleryOfflineStoreProvider), ref.watch(assetMediaRepositoryProvider));
});

final galleryOfflinePrefetchServiceProvider = Provider<GalleryOfflinePrefetchService>((ref) {
  return GalleryOfflinePrefetchService(
    scopeResolver: ref.watch(galleryOfflineScopeResolverProvider),
    store: ref.watch(galleryOfflineStoreProvider),
    remoteAssets: ref.watch(driftProvider).remoteAssetRepository,
    downloads: ref.watch(downloadRepositoryProvider),
    backgroundSync: ref.watch(backgroundSyncProvider),
    connectivityApi: ref.watch(connectivityApiProvider),
    localAlbums: LocalAlbumService(ref.watch(driftProvider).localAlbumRepository),
  );
});

final galleryOfflineRemoteAlbumsProvider = FutureProvider<List<RemoteAlbum>>((ref) {
  return ref.watch(remoteAlbumServiceProvider).getAll();
});

final galleryOfflinePinnedIdsProvider = AsyncNotifierProvider<GalleryOfflinePinnedIdsNotifier, Set<String>>(
  GalleryOfflinePinnedIdsNotifier.new,
);

final galleryOfflinePolicyProvider = AsyncNotifierProvider<GalleryOfflinePolicyNotifier, GalleryOfflinePolicy>(
  GalleryOfflinePolicyNotifier.new,
);

final galleryOfflineStatsProvider = AsyncNotifierProvider<GalleryOfflineStatsNotifier, GalleryOfflineStats>(
  GalleryOfflineStatsNotifier.new,
);

final galleryOfflinePrefetchProvider = NotifierProvider<GalleryOfflinePrefetchNotifier, GalleryOfflinePrefetchProgress>(
  GalleryOfflinePrefetchNotifier.new,
);

class GalleryOfflinePolicyNotifier extends AsyncNotifier<GalleryOfflinePolicy> {
  GalleryOfflineStore get _store => ref.read(galleryOfflineStoreProvider);

  @override
  Future<GalleryOfflinePolicy> build() => _store.loadPolicy();

  Future<void> updatePolicy(GalleryOfflinePolicy Function(GalleryOfflinePolicy current) update) async {
    final current = state.value ?? GalleryOfflinePolicy.defaults;
    final next = update(current);
    state = AsyncData(next);
    await _store.savePolicy(next);
  }

  Future<void> setEnabled(bool enabled) => updatePolicy((p) => p.copyWith(enabled: enabled));

  Future<void> setLimitBytes(int limitBytes) => updatePolicy((p) => p.copyWith(limitBytes: limitBytes));

  Future<void> setKeepMonths(int keepMonths) => updatePolicy((p) => p.copyWith(keepMonths: keepMonths));

  Future<void> setIncludeRecentMonths(bool includeRecentMonths) =>
      updatePolicy((p) => p.copyWith(includeRecentMonths: includeRecentMonths));

  Future<void> setIncludeFavorites(bool includeFavorites) =>
      updatePolicy((p) => p.copyWith(includeFavorites: includeFavorites));

  Future<void> toggleAlbum(String albumId) => updatePolicy((p) => p.toggleAlbum(albumId));

  Future<void> setWifiOnly(bool wifiOnly) => updatePolicy((p) => p.copyWith(wifiOnly: wifiOnly));

  Future<void> setPrefetchOnOpen(bool prefetchOnOpen) =>
      updatePolicy((p) => p.copyWith(prefetchOnOpen: prefetchOnOpen));
}

class GalleryOfflinePinnedIdsNotifier extends AsyncNotifier<Set<String>> {
  GalleryOfflineStore get _store => ref.read(galleryOfflineStoreProvider);

  @override
  Future<Set<String>> build() => _store.loadPinnedIds();

  Future<void> refresh() async {
    state = AsyncData(await _store.loadPinnedIds());
  }

  bool isPinned(String assetId) => state.value?.contains(assetId) ?? false;
}

class GalleryOfflineStatsNotifier extends AsyncNotifier<GalleryOfflineStats> {
  GalleryOfflineStore get _store => ref.read(galleryOfflineStoreProvider);

  @override
  Future<GalleryOfflineStats> build() => _store.stats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _store.stats());
  }

  Future<void> clearManagedIndex() async {
    state = const AsyncLoading();
    await _store.clearIndex();
    state = AsyncData(await _store.stats());
  }

  Future<void> applyEviction(GalleryOfflinePolicy policy) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      await refresh();
      return;
    }
    final pinned = await ref.read(galleryOfflineStoreProvider).loadPinnedIds();
    final targets = await ref
        .read(galleryOfflineScopeResolverProvider)
        .resolve(userId: user.id, policy: policy, pinnedIds: pinned);
    final keep = {for (final t in targets) t.assetId};
    state = const AsyncLoading();
    state = AsyncData(await ref.read(galleryOfflineEvictionProvider).apply(policy, keepAssetIds: keep));
  }
}

class GalleryOfflinePrefetchNotifier extends Notifier<GalleryOfflinePrefetchProgress> {
  @override
  GalleryOfflinePrefetchProgress build() => GalleryOfflinePrefetchProgress.idle;

  GalleryOfflinePrefetchService get _service => ref.read(galleryOfflinePrefetchServiceProvider);

  Future<void> start({bool ignorePrefetchOnOpenFlag = true}) async {
    if (!Platform.isAndroid) {
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const GalleryOfflinePrefetchProgress(
        status: GalleryOfflinePrefetchStatus.error,
        message: 'Not logged in',
      );
      return;
    }

    final policy = await ref.read(galleryOfflinePolicyProvider.future);
    if (!ignorePrefetchOnOpenFlag && !policy.prefetchOnOpen) {
      return;
    }

    state = const GalleryOfflinePrefetchProgress(status: GalleryOfflinePrefetchStatus.running);
    final result = await _service.run(
      policy: policy,
      userId: user.id,
      onProgress: (progress) {
        state = progress;
      },
    );
    state = result;
    if (result.status == GalleryOfflinePrefetchStatus.completed) {
      final latestPolicy = await ref.read(galleryOfflinePolicyProvider.future);
      await ref.read(galleryOfflineStatsProvider.notifier).applyEviction(latestPolicy);
    } else {
      await ref.read(galleryOfflineStatsProvider.notifier).refresh();
    }
  }

  Future<void> maybeStartOnOpen() async {
    if (!Platform.isAndroid) {
      return;
    }
    final policy = await ref.read(galleryOfflinePolicyProvider.future);
    if (!policy.enabled || !policy.prefetchOnOpen) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await start(ignorePrefetchOnOpenFlag: false);
  }

  Future<void> pinAssets(List<RemoteAsset> assets) async {
    if (!Platform.isAndroid || assets.isEmpty) {
      return;
    }
    await _service.downloadAndPin(assets);
    await ref.read(galleryOfflinePinnedIdsProvider.notifier).refresh();
    await ref.read(galleryOfflineStatsProvider.notifier).refresh();
  }

  Future<void> unpinAssets(Iterable<String> assetIds) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _service.unpin(assetIds);
    await ref.read(galleryOfflinePinnedIdsProvider.notifier).refresh();
    await ref.read(galleryOfflineStatsProvider.notifier).refresh();
  }

  void pause() {
    _service.pause();
  }
}
