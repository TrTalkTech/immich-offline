enum GalleryOfflinePrefetchStatus { idle, running, paused, completed, wifiBlocked, error }

class GalleryOfflinePrefetchProgress {
  const GalleryOfflinePrefetchProgress({
    required this.status,
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.skipped = 0,
    this.message,
  });

  final GalleryOfflinePrefetchStatus status;
  final int total;
  final int completed;
  final int failed;
  final int skipped;
  final String? message;

  static const idle = GalleryOfflinePrefetchProgress(status: GalleryOfflinePrefetchStatus.idle);

  int get processed => completed + failed + skipped;

  double? get fraction {
    if (total <= 0) {
      return null;
    }
    return (processed / total).clamp(0.0, 1.0);
  }

  GalleryOfflinePrefetchProgress copyWith({
    GalleryOfflinePrefetchStatus? status,
    int? total,
    int? completed,
    int? failed,
    int? skipped,
    String? message,
  }) {
    return GalleryOfflinePrefetchProgress(
      status: status ?? this.status,
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      skipped: skipped ?? this.skipped,
      message: message,
    );
  }
}
