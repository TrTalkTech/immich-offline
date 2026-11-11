/// Tracks a remote asset we downloaded (or adopted) into the device gallery.
class GalleryOfflineEntry {
  const GalleryOfflineEntry({
    required this.assetId,
    required this.pinned,
    required this.downloadedAt,
    this.estimatedBytes = 0,
    this.localId,
  });

  final String assetId;
  final bool pinned;
  final DateTime downloadedAt;
  final int estimatedBytes;

  /// Local MediaStore / PH id when known (after sync + hash).
  final String? localId;

  GalleryOfflineEntry copyWith({
    bool? pinned,
    DateTime? downloadedAt,
    int? estimatedBytes,
    String? localId,
    bool clearLocalId = false,
  }) {
    return GalleryOfflineEntry(
      assetId: assetId,
      pinned: pinned ?? this.pinned,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      estimatedBytes: estimatedBytes ?? this.estimatedBytes,
      localId: clearLocalId ? null : (localId ?? this.localId),
    );
  }

  Map<String, Object?> toJson() => {
    'assetId': assetId,
    'pinned': pinned,
    'downloadedAt': downloadedAt.toUtc().toIso8601String(),
    'estimatedBytes': estimatedBytes,
    'localId': localId,
  };

  factory GalleryOfflineEntry.fromJson(Map<String, Object?> json) {
    return GalleryOfflineEntry(
      assetId: json['assetId'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      estimatedBytes: (json['estimatedBytes'] as num?)?.toInt() ?? 0,
      localId: json['localId'] as String?,
    );
  }
}
