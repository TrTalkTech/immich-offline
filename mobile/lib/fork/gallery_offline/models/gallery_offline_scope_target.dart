class GalleryOfflineScopeTarget {
  const GalleryOfflineScopeTarget({
    required this.assetId,
    required this.createdAt,
    this.protected = false,
    this.estimatedBytes = 0,
  });

  final String assetId;
  final DateTime createdAt;

  /// Album-scoped or manually pinned — skip date-window eviction.
  final bool protected;

  /// From remote exif fileSize when available.
  final int estimatedBytes;

  GalleryOfflineScopeTarget copyWith({bool? protected, int? estimatedBytes}) {
    return GalleryOfflineScopeTarget(
      assetId: assetId,
      createdAt: createdAt,
      protected: protected ?? this.protected,
      estimatedBytes: estimatedBytes ?? this.estimatedBytes,
    );
  }
}
