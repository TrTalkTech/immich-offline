import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/fork/gallery_offline/gallery_offline_limit.dart';

void main() {
  group('shouldSkipForStorageLimit', () {
    test('downloads the first item when it fits', () {
      expect(
        shouldSkipForStorageLimit(
          protected: false,
          usedBytes: 0,
          estimatedBytes: 20 * 1024,
          limitBytes: 256 * 1024,
        ),
        isFalse,
      );
    });

    test('skips the first item when it alone exceeds the limit', () {
      expect(
        shouldSkipForStorageLimit(
          protected: false,
          usedBytes: 0,
          estimatedBytes: 2 * 1024 * 1024,
          limitBytes: 256 * 1024,
        ),
        isTrue,
      );
    });

    test('skips later items in the same batch once used would overflow', () {
      var used = 0;
      const limit = 50 * 1024;
      const sizes = [20 * 1024, 20 * 1024, 20 * 1024];
      final accepted = <int>[];
      for (final size in sizes) {
        if (shouldSkipForStorageLimit(
          protected: false,
          usedBytes: used,
          estimatedBytes: size,
          limitBytes: limit,
        )) {
          continue;
        }
        accepted.add(size);
        used += projectedAddBytes(size);
      }
      expect(accepted, [20 * 1024, 20 * 1024]);
      expect(used, 40 * 1024);
    });

    test('still downloads protected assets after the limit is reached', () {
      expect(
        shouldSkipForStorageLimit(
          protected: true,
          usedBytes: 256 * 1024,
          estimatedBytes: 20 * 1024,
          limitBytes: 256 * 1024,
        ),
        isFalse,
      );
    });
  });
}
