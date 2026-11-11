/// Whether a non-protected target should be skipped because it would exceed
/// the gallery-offline storage limit. Protected/pinned assets always download.
bool shouldSkipForStorageLimit({
  required bool protected,
  required int usedBytes,
  required int estimatedBytes,
  required int limitBytes,
}) {
  if (protected) {
    return false;
  }
  final add = estimatedBytes > 0 ? estimatedBytes : 1;
  return usedBytes >= limitBytes || usedBytes + add > limitBytes;
}

/// Bytes to count toward the running used total after accepting a target.
int projectedAddBytes(int estimatedBytes) => estimatedBytes > 0 ? estimatedBytes : 1;
