import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_policy.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_prefetch_progress.dart';
import 'package:immich_mobile/fork/gallery_offline/models/gallery_offline_stats.dart';
import 'package:immich_mobile/fork/gallery_offline/providers/gallery_offline.provider.dart';
import 'package:immich_mobile/utils/bytes_units.dart';
import 'package:immich_ui/immich_ui.dart';

class GalleryOfflineSettingsPage extends HookConsumerWidget {
  const GalleryOfflineSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(galleryOfflinePolicyProvider);
    final statsAsync = ref.watch(galleryOfflineStatsProvider);
    final prefetch = ref.watch(galleryOfflinePrefetchProvider);
    final pinnedAsync = ref.watch(galleryOfflinePinnedIdsProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Gallery offline')),
      body: policyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load settings\n$error')),
        data: (policy) {
          final stats = statsAsync.value ?? GalleryOfflineStats.empty;
          final pinnedCount = pinnedAsync.value?.length ?? stats.pinnedCount;
          return _Body(
            policy: policy,
            stats: stats,
            statsLoading: statsAsync.isLoading,
            prefetch: prefetch,
            pinnedCount: pinnedCount,
          );
        },
      ),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({
    required this.policy,
    required this.stats,
    required this.statsLoading,
    required this.prefetch,
    required this.pinnedCount,
  });

  final GalleryOfflinePolicy policy;
  final GalleryOfflineStats stats;
  final bool statsLoading;
  final GalleryOfflinePrefetchProgress prefetch;
  final int pinnedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = useValueNotifier(policy.enabled);
    final includeRecentMonths = useValueNotifier(policy.includeRecentMonths);
    final includeFavorites = useValueNotifier(policy.includeFavorites);
    final wifiOnly = useValueNotifier(policy.wifiOnly);
    final prefetchOnOpen = useValueNotifier(policy.prefetchOnOpen);

    useEffect(() {
      enabled.value = policy.enabled;
      includeRecentMonths.value = policy.includeRecentMonths;
      includeFavorites.value = policy.includeFavorites;
      wifiOnly.value = policy.wifiOnly;
      prefetchOnOpen.value = policy.prefetchOnOpen;
      return null;
    }, [policy]);

    final policyNotifier = ref.read(galleryOfflinePolicyProvider.notifier);
    final statsNotifier = ref.read(galleryOfflineStatsProvider.notifier);
    final prefetchNotifier = ref.read(galleryOfflinePrefetchProvider.notifier);
    final usedLabel = statsLoading
        ? 'Calculating…'
        : '${formatBytes(stats.usedBytes)} / ${formatBytes(policy.limitBytes)} · ${stats.fileCount} files · $pinnedCount pinned';
    final isRunning = prefetch.status == GalleryOfflinePrefetchStatus.running;

    return SettingsSubPageScaffold(
      showDivider: true,
      settings: [
        SettingsSwitchListTile(
          valueNotifier: enabled,
          title: 'Enable gallery offline',
          subtitle: 'Download originals into DCIM/Immich (Android gallery)',
          onChanged: policyNotifier.setEnabled,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text('Used', style: context.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text(usedLabel, style: context.textTheme.bodyMedium),
          trailing: IconButton(
            tooltip: 'Refresh',
            onPressed: statsLoading ? null : () => statsNotifier.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ),
        const SettingGroupTitle(title: 'Storage limit', subtitle: 'Prefetch stops when the limit is reached'),
        SettingsRadioListTile<int>(
          groupBy: GalleryOfflinePolicy.limitChoicesBytes.contains(policy.limitBytes)
              ? policy.limitBytes
              : 5 * GalleryOfflinePolicy.gb,
          groups: [
            for (final bytes in GalleryOfflinePolicy.limitChoicesBytes)
              SettingsRadioGroup(title: GalleryOfflinePolicy.limitLabel(bytes), value: bytes),
          ],
          onRadioChanged: (value) {
            if (value == null) {
              return;
            }
            policyNotifier.setLimitBytes(value);
          },
        ),
        SettingsSwitchListTile(
          valueNotifier: wifiOnly,
          title: 'Wi‑Fi only',
          subtitle: 'Prefetch only on unmetered networks',
          onChanged: policyNotifier.setWifiOnly,
        ),
        SettingsSwitchListTile(
          valueNotifier: prefetchOnOpen,
          title: 'Prefetch when app opens',
          subtitle: 'Start downloading in the background after launch',
          onChanged: policyNotifier.setPrefetchOnOpen,
        ),
        const SettingGroupTitle(title: 'By time', subtitle: 'Keep recent timeline photos offline'),
        SettingsSwitchListTile(
          valueNotifier: includeRecentMonths,
          title: 'Recent photos',
          subtitle: 'Download images from the last N months',
          onChanged: policyNotifier.setIncludeRecentMonths,
        ),
        if (policy.includeRecentMonths)
          SettingsRadioListTile<int>(
            groupBy: policy.keepMonths,
            groups: [
              for (final months in GalleryOfflinePolicy.keepMonthsChoices)
                SettingsRadioGroup(title: '$months months', value: months),
            ],
            onRadioChanged: (value) {
              if (value == null) {
                return;
              }
              policyNotifier.setKeepMonths(value);
            },
          ),
        SettingsSwitchListTile(
          valueNotifier: includeFavorites,
          title: 'Favorites',
          subtitle: 'Download all favorite remote images (heart)',
          onChanged: policyNotifier.setIncludeFavorites,
        ),
        const SettingGroupTitle(
          title: 'By albums',
          subtitle: 'Selected albums are protected from time-window eviction',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _RemoteAlbumsSection(
            selectedAlbumIds: policy.selectedAlbumIdSet,
            onAlbumToggled: policyNotifier.toggleAlbum,
          ),
        ),
        const SettingGroupTitle(title: 'Download'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_scopeSummary(policy), style: context.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(_prefetchLabel(prefetch), style: context.textTheme.bodySmall),
        ),
        if (prefetch.fraction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: LinearProgressIndicator(value: prefetch.fraction),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.download_outlined),
          title: const Text('Download now'),
          subtitle: const Text('Enqueue missing originals for the current scope'),
          onTap: isRunning ? null : () => prefetchNotifier.start(),
        ),
        if (isRunning)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.pause),
            title: const Text('Pause'),
            onTap: prefetchNotifier.pause,
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Apply eviction'),
          subtitle: const Text('Remove out-of-scope gallery copies (keeps pins)'),
          onTap: () => statsNotifier.applyEviction(policy),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.delete_outline, color: context.colorScheme.error),
          title: Text('Clear managed index', style: TextStyle(color: context.colorScheme.error)),
          subtitle: const Text('Does not delete gallery files — only forgets the fork index'),
          onTap: statsNotifier.clearManagedIndex,
        ),
      ],
    );
  }

  static String _scopeSummary(GalleryOfflinePolicy policy) {
    final parts = <String>[];
    if (policy.includeRecentMonths) {
      parts.add('last ${policy.keepMonths} months');
    }
    if (policy.includeFavorites) {
      parts.add('favorites');
    }
    if (policy.selectedAlbumIds.isNotEmpty) {
      parts.add('${policy.selectedAlbumIds.length} album(s)');
    }
    if (parts.isEmpty) {
      return 'Select recent photos, favorites, and/or albums. Pin individual photos from the action sheet.';
    }
    return 'Downloads originals for ${parts.join(' · ')}';
  }

  static String _prefetchLabel(GalleryOfflinePrefetchProgress prefetch) {
    final counts = prefetch.total > 0
        ? '${prefetch.processed}/${prefetch.total} · ok ${prefetch.completed} · skip ${prefetch.skipped} · fail ${prefetch.failed}'
        : null;
    final status = switch (prefetch.status) {
      GalleryOfflinePrefetchStatus.idle => 'Idle',
      GalleryOfflinePrefetchStatus.running => 'Running',
      GalleryOfflinePrefetchStatus.paused => 'Paused',
      GalleryOfflinePrefetchStatus.completed => 'Completed',
      GalleryOfflinePrefetchStatus.wifiBlocked => 'Waiting for Wi‑Fi',
      GalleryOfflinePrefetchStatus.error => 'Error',
    };
    final parts = <String>[status];
    if (counts != null) {
      parts.add(counts);
    }
    if (prefetch.message != null && prefetch.message!.isNotEmpty) {
      parts.add(prefetch.message!);
    }
    return parts.join(' · ');
  }
}

class _RemoteAlbumsSection extends ConsumerWidget {
  const _RemoteAlbumsSection({required this.selectedAlbumIds, required this.onAlbumToggled});

  final Set<String> selectedAlbumIds;
  final ValueChanged<String> onAlbumToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(galleryOfflineRemoteAlbumsProvider);

    return albumsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (error, _) => Text(
        'Could not load albums\n$error',
        style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.error),
      ),
      data: (albums) {
        if (albums.isEmpty) {
          return Text(
            'No library albums found',
            style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurface.withValues(alpha: 0.6)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: context.colorScheme.outlineVariant),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          constraints: const BoxConstraints(maxHeight: 240),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final isSelected = selectedAlbumIds.contains(album.id);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(album.name),
                  subtitle: album.assetCount > 0 ? Text('${album.assetCount} items') : null,
                  onChanged: (_) => onAlbumToggled(album.id),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
