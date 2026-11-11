class GalleryOfflineStats {
  const GalleryOfflineStats({required this.usedBytes, required this.fileCount, required this.pinnedCount});

  final int usedBytes;
  final int fileCount;
  final int pinnedCount;

  static const empty = GalleryOfflineStats(usedBytes: 0, fileCount: 0, pinnedCount: 0);
}
