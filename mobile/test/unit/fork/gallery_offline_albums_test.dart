import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/fork/gallery_offline/gallery_offline_albums.dart';

import '../factories/local_album_factory.dart';

void main() {
  test('recognizes the Immich gallery-offline album', () {
    expect(isGalleryOfflineLocalAlbum(LocalAlbumFactory.create(name: 'Immich')), isTrue);
    expect(isGalleryOfflineLocalAlbum(LocalAlbumFactory.create(name: 'immich')), isTrue);
    expect(isGalleryOfflineLocalAlbum(LocalAlbumFactory.create(name: 'DCIM/Immich')), isTrue);
    expect(isGalleryOfflineLocalAlbum(LocalAlbumFactory.create(name: 'Camera')), isFalse);
    expect(isGalleryOfflineLocalAlbum(LocalAlbumFactory.create(name: 'Screenshots')), isFalse);
  });
}
