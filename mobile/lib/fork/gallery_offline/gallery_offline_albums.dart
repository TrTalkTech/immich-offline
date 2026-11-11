import 'package:immich_mobile/domain/models/album/local_album.model.dart';

/// Device gallery album that gallery-offline writes into (`DCIM/Immich`).
bool isGalleryOfflineLocalAlbum(LocalAlbum album) {
  final name = album.name.toLowerCase();
  return name == 'immich' || album.name.contains('DCIM/Immich');
}
