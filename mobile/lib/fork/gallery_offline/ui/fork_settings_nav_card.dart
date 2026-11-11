import 'package:flutter/material.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/fork/gallery_offline/ui/gallery_offline_settings_page.dart';

/// Settings entry that avoids auto_route / SettingsCard PageRouteInfo.
class ForkSettingsNavCard extends StatelessWidget {
  const ForkSettingsNavCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: context.colorScheme.surfaceContainer,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          leading: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              color: context.isDarkTheme ? Colors.black26 : Colors.white.withAlpha(100),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Icon(Icons.offline_pin_outlined, color: context.primaryColor),
          ),
          title: Text('Gallery offline', style: context.textTheme.titleMedium!.copyWith(color: context.primaryColor)),
          subtitle: Text(
            'Download originals to the phone gallery for offline viewing',
            style: context.textTheme.bodyMedium,
          ),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GalleryOfflineSettingsPage()));
          },
        ),
      ),
    );
  }
}
