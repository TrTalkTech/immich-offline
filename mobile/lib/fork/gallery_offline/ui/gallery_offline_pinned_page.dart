import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/fork/gallery_offline/providers/gallery_offline.provider.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/general_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/widgets/common/mesmerizing_sliver_app_bar.dart';

/// Lists assets manually pinned for gallery offline (Android).
/// Opened via Navigator — no auto_route registration.
class GalleryOfflinePinnedPage extends ConsumerWidget {
  const GalleryOfflinePinnedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(galleryOfflinePinnedIdsProvider);

    return pinnedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Pinned')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Pinned')),
        body: Center(child: Text('Failed to load pinned\n$error')),
      ),
      data: (pinnedIds) {
        if (pinnedIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pinned')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pinned photos yet.\nSelect photos and choose “Pin offline” in the action sheet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return FutureBuilder<List<BaseAsset>>(
          future: _loadAssets(ref, pinnedIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                appBar: AppBar(title: const Text('Pinned')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final assets = snapshot.data ?? const <BaseAsset>[];
            if (assets.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Pinned')),
                body: const Center(
                  child: Text('Pinned IDs found, but assets are missing from the local library sync.'),
                ),
              );
            }

            return ProviderScope(
              overrides: [
                timelineServiceProvider.overrideWith((ref) {
                  final timelineService = ref
                      .watch(timelineFactoryProvider)
                      .fromAssetsWithBuckets(assets, TimelineOrigin.search);
                  ref.onDispose(timelineService.dispose);
                  return timelineService;
                }),
              ],
              child: Timeline(
                appBar: const MesmerizingSliverAppBar(title: 'Pinned'),
                bottomSheet: const GeneralBottomSheet(),
                groupBy: GroupAssetsBy.day,
              ),
            );
          },
        );
      },
    );
  }

  static Future<List<BaseAsset>> _loadAssets(WidgetRef ref, Set<String> pinnedIds) async {
    final repo = ref.read(driftProvider).remoteAssetRepository;
    final assets = <BaseAsset>[];
    for (final id in pinnedIds) {
      final asset = await repo.get(id);
      if (asset != null) {
        assets.add(asset);
      }
    }
    assets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return assets;
  }
}
