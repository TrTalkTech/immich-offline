import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/enums.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/fork/gallery_offline/providers/gallery_offline.provider.dart';
import 'package:immich_mobile/presentation/actions/action.dart';
import 'package:immich_mobile/providers/infrastructure/toast.provider.dart';
import 'package:immich_mobile/utils/error_handler.dart';

typedef _PinState = ({bool shouldPin, List<RemoteAsset> assets});

final _pinStateProvider = Provider.family.autoDispose<_PinState?, ActionSource>((ref, source) {
  if (!Platform.isAndroid) {
    return null;
  }

  final assets = ref.watch(assetsActionProvider(source)).remote().toList(growable: false);
  if (assets.isEmpty) {
    return null;
  }

  final pinned = ref.watch(galleryOfflinePinnedIdsProvider).value ?? {};
  final unpinned = assets.where((a) => !pinned.contains(a.id)).toList(growable: false);
  final shouldPin = unpinned.isNotEmpty;
  return (shouldPin: shouldPin, assets: shouldPin ? unpinned : assets);
}, dependencies: [assetsActionProvider, galleryOfflinePinnedIdsProvider]);

/// Android-only: pin / unpin selected remote assets into the phone gallery.
class PinAction extends AssetActionBuilder {
  const PinAction({required super.source});

  @override
  ActionItem? create(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_pinStateProvider(source));
    if (state == null) {
      return null;
    }

    return ActionItem(
      icon: state.shouldPin ? Icons.push_pin_outlined : Icons.push_pin,
      label: state.shouldPin ? 'Pin offline' : 'Unpin',
      onAction: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final state = ref.read(_pinStateProvider(source));
    if (state == null) {
      return;
    }

    final toast = ref.read(toastServiceProvider);
    final clearSelection = ref.read(clearSelectionProvider(source));
    final prefetch = ref.read(galleryOfflinePrefetchProvider.notifier);

    try {
      if (state.shouldPin) {
        await prefetch.pinAssets(state.assets);
        toast.success('Pinned ${state.assets.length} to gallery offline');
      } else {
        await prefetch.unpinAssets(state.assets.map((a) => a.id));
        toast.success('Unpinned ${state.assets.length}');
      }
      clearSelection();
    } catch (error, stack) {
      handleError(error, stack: stack, description: 'Failed to update pin status');
    }
  }
}
