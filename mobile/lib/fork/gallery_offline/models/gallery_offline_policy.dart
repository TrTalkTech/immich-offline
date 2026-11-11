/// User-controlled gallery offline policy.
///
/// Stored outside Immich SettingsKey / StoreKey / Drift to avoid upstream merges.
/// Downloads always use Immich original → device gallery (DCIM/Immich on Android).
class GalleryOfflinePolicy {
  const GalleryOfflinePolicy({
    required this.enabled,
    required this.limitBytes,
    required this.keepMonths,
    required this.includeRecentMonths,
    required this.includeFavorites,
    required this.selectedAlbumIds,
    required this.wifiOnly,
    required this.prefetchOnOpen,
  });

  final bool enabled;
  final int limitBytes;

  /// Keep remote images from the last N months (when [includeRecentMonths] is true).
  final int keepMonths;
  final bool includeRecentMonths;

  /// Cache favorite remote images.
  final bool includeFavorites;

  /// Cache images from these remote (server) album IDs.
  final List<String> selectedAlbumIds;

  final bool wifiOnly;
  final bool prefetchOnOpen;

  static const int kb = 1024;
  static const int gb = 1024 * 1024 * 1024;

  static const GalleryOfflinePolicy defaults = GalleryOfflinePolicy(
    enabled: false,
    limitBytes: 5 * gb,
    keepMonths: 6,
    includeRecentMonths: true,
    includeFavorites: false,
    selectedAlbumIds: [],
    wifiOnly: true,
    prefetchOnOpen: true,
  );

  static const List<int> limitChoicesGb = [1, 2, 5, 10, 20, 50];
  static const List<int> limitChoicesBytes = [256 * kb, 1 * gb, 2 * gb, 5 * gb, 10 * gb, 20 * gb, 50 * gb];
  static const List<int> keepMonthsChoices = [3, 6, 12];

  static String limitLabel(int bytes) {
    if (bytes < gb) {
      return '${(bytes / kb).round()} KB';
    }
    return '${bytes ~/ gb} GB';
  }

  Set<String> get selectedAlbumIdSet => selectedAlbumIds.toSet();

  GalleryOfflinePolicy copyWith({
    bool? enabled,
    int? limitBytes,
    int? keepMonths,
    bool? includeRecentMonths,
    bool? includeFavorites,
    List<String>? selectedAlbumIds,
    bool? wifiOnly,
    bool? prefetchOnOpen,
  }) {
    return GalleryOfflinePolicy(
      enabled: enabled ?? this.enabled,
      limitBytes: limitBytes ?? this.limitBytes,
      keepMonths: keepMonths ?? this.keepMonths,
      includeRecentMonths: includeRecentMonths ?? this.includeRecentMonths,
      includeFavorites: includeFavorites ?? this.includeFavorites,
      selectedAlbumIds: selectedAlbumIds ?? this.selectedAlbumIds,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      prefetchOnOpen: prefetchOnOpen ?? this.prefetchOnOpen,
    );
  }

  GalleryOfflinePolicy toggleAlbum(String albumId) {
    final next = selectedAlbumIdSet;
    if (!next.add(albumId)) {
      next.remove(albumId);
    }
    final sorted = next.toList()..sort();
    return copyWith(selectedAlbumIds: sorted);
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'limitBytes': limitBytes,
    'keepMonths': keepMonths,
    'includeRecentMonths': includeRecentMonths,
    'includeFavorites': includeFavorites,
    'selectedAlbumIds': selectedAlbumIds,
    'wifiOnly': wifiOnly,
    'prefetchOnOpen': prefetchOnOpen,
  };

  factory GalleryOfflinePolicy.fromJson(Map<String, Object?> json) {
    final limit = (json['limitBytes'] as num?)?.toInt() ?? defaults.limitBytes;
    final months = (json['keepMonths'] as num?)?.toInt() ?? defaults.keepMonths;
    final rawAlbums = json['selectedAlbumIds'];
    final albums = <String>[];
    if (rawAlbums is List) {
      for (final item in rawAlbums) {
        if (item is String && item.isNotEmpty) {
          albums.add(item);
        }
      }
      albums.sort();
    }

    final clampedLimit = limitChoicesBytes.contains(limit)
        ? limit
        : (limit > 50 * gb ? 50 * gb : (limit > 0 ? limit : defaults.limitBytes));

    return GalleryOfflinePolicy(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      limitBytes: clampedLimit,
      keepMonths: keepMonthsChoices.contains(months) ? months : defaults.keepMonths,
      includeRecentMonths: json['includeRecentMonths'] as bool? ?? defaults.includeRecentMonths,
      includeFavorites: json['includeFavorites'] as bool? ?? defaults.includeFavorites,
      selectedAlbumIds: albums,
      wifiOnly: json['wifiOnly'] as bool? ?? defaults.wifiOnly,
      prefetchOnOpen: json['prefetchOnOpen'] as bool? ?? defaults.prefetchOnOpen,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GalleryOfflinePolicy &&
        other.enabled == enabled &&
        other.limitBytes == limitBytes &&
        other.keepMonths == keepMonths &&
        other.includeRecentMonths == includeRecentMonths &&
        other.includeFavorites == includeFavorites &&
        _listEquals(other.selectedAlbumIds, selectedAlbumIds) &&
        other.wifiOnly == wifiOnly &&
        other.prefetchOnOpen == prefetchOnOpen;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    limitBytes,
    keepMonths,
    includeRecentMonths,
    includeFavorites,
    Object.hashAll(selectedAlbumIds),
    wifiOnly,
    prefetchOnOpen,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
