import 'dart:convert';
import 'dart:io';

import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_entry.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_stats.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File-backed store for policy, pin set, and gallery download index.
class GalleryOfflineStore {
  GalleryOfflineStore();

  static const _rootFolderName = 'fork_gallery_offline';
  static const _policyFileName = 'policy.json';
  static const _pinsFileName = 'pins.json';
  static const _indexFileName = 'index.json';

  Future<Directory> rootDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, _rootFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String name) async {
    final root = await rootDirectory();
    return File(p.join(root.path, name));
  }

  Future<GalleryOfflinePolicy> loadPolicy() async {
    final file = await _file(_policyFileName);
    if (!await file.exists()) {
      return GalleryOfflinePolicy.defaults;
    }
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return GalleryOfflinePolicy.fromJson(Map<String, Object?>.from(map));
    } catch (_) {
      return GalleryOfflinePolicy.defaults;
    }
  }

  Future<void> savePolicy(GalleryOfflinePolicy policy) async {
    final file = await _file(_policyFileName);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(policy.toJson()));
  }

  Future<Set<String>> loadPinnedIds() async {
    final file = await _file(_pinsFileName);
    if (!await file.exists()) {
      return {};
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) {
        return {};
      }
      return {
        for (final item in raw)
          if (item is String && item.isNotEmpty) item,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> savePinnedIds(Set<String> ids) async {
    final file = await _file(_pinsFileName);
    final sorted = ids.toList()..sort();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(sorted));
  }

  Future<Map<String, GalleryOfflineEntry>> loadIndex() async {
    final file = await _file(_indexFileName);
    if (!await file.exists()) {
      return {};
    }
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) {
        return {};
      }
      final map = <String, GalleryOfflineEntry>{};
      for (final item in raw) {
        if (item is Map) {
          final entry = GalleryOfflineEntry.fromJson(Map<String, Object?>.from(item));
          if (entry.assetId.isNotEmpty) {
            map[entry.assetId] = entry;
          }
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveIndex(Map<String, GalleryOfflineEntry> index) async {
    final file = await _file(_indexFileName);
    final list = index.values.map((e) => e.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(list));
  }

  Future<GalleryOfflineStats> stats() async {
    final index = await loadIndex();
    var used = 0;
    var pinned = 0;
    for (final entry in index.values) {
      used += entry.estimatedBytes;
      if (entry.pinned) {
        pinned++;
      }
    }
    return GalleryOfflineStats(usedBytes: used, fileCount: index.length, pinnedCount: pinned);
  }

  Future<void> upsertEntry(GalleryOfflineEntry entry) async {
    final index = await loadIndex();
    final existing = index[entry.assetId];
    index[entry.assetId] = existing == null
        ? entry
        : existing.copyWith(
            pinned: entry.pinned || existing.pinned,
            downloadedAt: entry.downloadedAt,
            estimatedBytes: entry.estimatedBytes > 0 ? entry.estimatedBytes : existing.estimatedBytes,
            localId: entry.localId,
          );
    await saveIndex(index);
  }

  Future<void> removeEntries(Iterable<String> assetIds) async {
    final index = await loadIndex();
    var changed = false;
    for (final id in assetIds) {
      changed = index.remove(id) != null || changed;
    }
    if (changed) {
      await saveIndex(index);
    }
  }

  Future<void> clearIndex() async {
    await saveIndex({});
  }
}
