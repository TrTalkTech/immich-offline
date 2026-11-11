import 'package:drift/drift.dart';
import 'package:immich_mobile/data/db/main/database.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_scope_target.dart';

/// Resolves remote assets for gallery offline from local Drift sync DB.
///
/// Scope is a union of:
/// - recent months (optional)
/// - favorites (optional)
/// - selected remote albums (optional)
/// - manually pinned asset IDs (always protected)
class GalleryOfflineScopeResolver {
  const GalleryOfflineScopeResolver(this._db);

  final Drift _db;

  Future<List<GalleryOfflineScopeTarget>> resolve({
    required String userId,
    required GalleryOfflinePolicy policy,
    required Set<String> pinnedIds,
  }) async {
    final byId = <String, GalleryOfflineScopeTarget>{};

    void addAll(Iterable<GalleryOfflineScopeTarget> targets) {
      for (final target in targets) {
        final existing = byId[target.assetId];
        if (existing == null) {
          byId[target.assetId] = target;
        } else if (target.protected && !existing.protected) {
          byId[target.assetId] = existing.copyWith(protected: true);
        } else if (target.estimatedBytes > existing.estimatedBytes) {
          byId[target.assetId] = existing.copyWith(estimatedBytes: target.estimatedBytes);
        }
      }
    }

    if (policy.includeRecentMonths) {
      addAll(await _recentMonths(userId: userId, keepMonths: policy.keepMonths));
    }
    if (policy.includeFavorites) {
      addAll(await _favorites(userId: userId));
    }
    if (policy.selectedAlbumIds.isNotEmpty) {
      addAll(await _albums(albumIds: policy.selectedAlbumIds));
    }
    if (pinnedIds.isNotEmpty) {
      addAll(await _byIds(pinnedIds, protected: true));
    }

    final targets = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return targets;
  }

  Future<Set<String>> protectedAssetIds({
    required String userId,
    required GalleryOfflinePolicy policy,
    required Set<String> pinnedIds,
  }) async {
    final ids = <String>{...pinnedIds};
    if (policy.includeFavorites) {
      for (final t in await _favorites(userId: userId)) {
        ids.add(t.assetId);
      }
    }
    if (policy.selectedAlbumIds.isNotEmpty) {
      for (final t in await _albums(albumIds: policy.selectedAlbumIds)) {
        ids.add(t.assetId);
      }
    }
    return ids;
  }

  Future<List<GalleryOfflineScopeTarget>> _recentMonths({required String userId, required int keepMonths}) async {
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: keepMonths * 30));
    final query =
        _db.remoteAssetEntity.select().join([
            leftOuterJoin(_db.remoteExifEntity, _db.remoteExifEntity.assetId.equalsExp(_db.remoteAssetEntity.id)),
          ])
          ..where(
            _db.remoteAssetEntity.ownerId.equals(userId) &
                _db.remoteAssetEntity.deletedAt.isNull() &
                _db.remoteAssetEntity.visibility.equalsValue(AssetVisibility.timeline) &
                _db.remoteAssetEntity.type.equalsValue(AssetType.image) &
                _db.remoteAssetEntity.createdAt.isBiggerOrEqualValue(cutoff),
          )
          ..orderBy([OrderingTerm.desc(_db.remoteAssetEntity.createdAt)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        GalleryOfflineScopeTarget(
          assetId: row.readTable(_db.remoteAssetEntity).id,
          createdAt: row.readTable(_db.remoteAssetEntity).createdAt,
          estimatedBytes: row.readTableOrNull(_db.remoteExifEntity)?.fileSize ?? 0,
        ),
    ];
  }

  Future<List<GalleryOfflineScopeTarget>> _favorites({required String userId}) async {
    final query =
        _db.remoteAssetEntity.select().join([
            leftOuterJoin(_db.remoteExifEntity, _db.remoteExifEntity.assetId.equalsExp(_db.remoteAssetEntity.id)),
          ])
          ..where(
            _db.remoteAssetEntity.ownerId.equals(userId) &
                _db.remoteAssetEntity.deletedAt.isNull() &
                _db.remoteAssetEntity.isFavorite.equals(true) &
                _db.remoteAssetEntity.type.equalsValue(AssetType.image) &
                (_db.remoteAssetEntity.visibility.equalsValue(AssetVisibility.timeline) |
                    _db.remoteAssetEntity.visibility.equalsValue(AssetVisibility.archive)),
          )
          ..orderBy([OrderingTerm.desc(_db.remoteAssetEntity.createdAt)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        GalleryOfflineScopeTarget(
          assetId: row.readTable(_db.remoteAssetEntity).id,
          createdAt: row.readTable(_db.remoteAssetEntity).createdAt,
          protected: true,
          estimatedBytes: row.readTableOrNull(_db.remoteExifEntity)?.fileSize ?? 0,
        ),
    ];
  }

  Future<List<GalleryOfflineScopeTarget>> _albums({required List<String> albumIds}) async {
    final query =
        _db.remoteAlbumAssetEntity.select().join([
            innerJoin(_db.remoteAssetEntity, _db.remoteAssetEntity.id.equalsExp(_db.remoteAlbumAssetEntity.assetId)),
            leftOuterJoin(_db.remoteExifEntity, _db.remoteExifEntity.assetId.equalsExp(_db.remoteAssetEntity.id)),
          ])
          ..where(
            _db.remoteAlbumAssetEntity.albumId.isIn(albumIds) &
                _db.remoteAssetEntity.deletedAt.isNull() &
                _db.remoteAssetEntity.type.equalsValue(AssetType.image),
          )
          ..orderBy([OrderingTerm.desc(_db.remoteAssetEntity.createdAt)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        GalleryOfflineScopeTarget(
          assetId: row.readTable(_db.remoteAssetEntity).id,
          createdAt: row.readTable(_db.remoteAssetEntity).createdAt,
          protected: true,
          estimatedBytes: row.readTableOrNull(_db.remoteExifEntity)?.fileSize ?? 0,
        ),
    ];
  }

  Future<List<GalleryOfflineScopeTarget>> _byIds(Set<String> ids, {required bool protected}) async {
    if (ids.isEmpty) {
      return const [];
    }
    final query = _db.remoteAssetEntity.select().join([
      leftOuterJoin(_db.remoteExifEntity, _db.remoteExifEntity.assetId.equalsExp(_db.remoteAssetEntity.id)),
    ])..where(_db.remoteAssetEntity.id.isIn(ids.toList()) & _db.remoteAssetEntity.deletedAt.isNull());

    final rows = await query.get();
    return [
      for (final row in rows)
        GalleryOfflineScopeTarget(
          assetId: row.readTable(_db.remoteAssetEntity).id,
          createdAt: row.readTable(_db.remoteAssetEntity).createdAt,
          protected: protected,
          estimatedBytes: row.readTableOrNull(_db.remoteExifEntity)?.fileSize ?? 0,
        ),
    ];
  }
}
