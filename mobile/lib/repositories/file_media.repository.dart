import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:photo_manager/photo_manager.dart' hide AssetType;

final fileMediaRepositoryProvider = Provider((ref) => const FileMediaRepository());

class FileMediaRepository {
  const FileMediaRepository();

  Future<AssetEntity?> saveImageWithFile(
    String filePath, {
    String? title,
    String? relativePath,
    DateTime? creationDate,
    double? latitude,
    double? longitude,
  }) async {
    // FORK(gallery-offline): pass capture date/GPS so MediaStore DATE_TAKEN is not "now"
    final entity = await PhotoManager.editor.saveImageWithPath(
      filePath,
      title: title,
      relativePath: relativePath,
      creationDate: creationDate,
      latitude: latitude,
      longitude: longitude,
    );
    return entity;
  }

  Future<AssetEntity?> saveLivePhoto({required File image, required File video, required String title}) async {
    final entity = await PhotoManager.editor.darwin.saveLivePhoto(imageFile: image, videoFile: video, title: title);
    return entity;
  }

  Future<AssetEntity?> saveVideo(File file, {required String title, String? relativePath}) async {
    final entity = await PhotoManager.editor.saveVideo(file, title: title, relativePath: relativePath);
    return entity;
  }
}
