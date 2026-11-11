import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_entry.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_stats.dart';
import 'package:immich_mobile/fork/gallery_offline/services/gallery_offline_store.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';

/// Evicts gallery downloads that are outside the current scope / GB limit.
/// Never auto-deletes pinned entries.
class GalleryOfflineEviction {
  GalleryOfflineEviction(this._store, this._assetMedia);

  final GalleryOfflineStore _store;
  final AssetMediaRepository _assetMedia;

  Future<GalleryOfflineStats> apply(GalleryOfflinePolicy policy, {required Set<String> keepAssetIds}) async {
    final index = await _store.loadIndex();
    if (index.isEmpty) {
      return GalleryOfflineStats.empty;
    }

    final toRemove = <String>[];
    for (final entry in index.values) {
      if (entry.pinned || keepAssetIds.contains(entry.assetId)) {
        continue;
      }
      toRemove.add(entry.assetId);
    }
    await _deleteAndDrop(index, toRemove);

    var used = index.values.fold<int>(0, (sum, e) => sum + e.estimatedBytes);
    if (used > policy.limitBytes) {
      final candidates = index.values.where((e) => !e.pinned).toList()
        ..sort((a, b) => a.downloadedAt.compareTo(b.downloadedAt));

      final pressureRemove = <String>[];
      for (final entry in candidates) {
        if (used <= policy.limitBytes) {
          break;
        }
        pressureRemove.add(entry.assetId);
        used -= entry.estimatedBytes;
      }
      await _deleteAndDrop(index, pressureRemove);
    }

    await _store.saveIndex(index);
    return _store.stats();
  }

  Future<void> _deleteAndDrop(Map<String, GalleryOfflineEntry> index, List<String> assetIds) async {
    if (assetIds.isEmpty) {
      return;
    }
    final localIds = <String>[];
    for (final id in assetIds) {
      final localId = index[id]?.localId;
      if (localId != null && localId.isNotEmpty) {
        localIds.add(localId);
      }
      index.remove(id);
    }
    if (localIds.isNotEmpty) {
      try {
        await _assetMedia.deleteAll(localIds, trash: false);
      } catch (_) {
        // Index already dropped; leftover gallery files are acceptable.
      }
    }
  }
}
