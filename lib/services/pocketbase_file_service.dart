import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:flutter_freelance_platform/services/pocketbase_service.dart';

class PocketBaseFileService {
  PocketBaseFileService._();

  static String? firstFileName(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) {
        final trimmed = first.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }

    return null;
  }

  static String? fileUrl({
    required String collectionName,
    required String recordId,
    required dynamic fileValue,
  }) {
    final fileName = firstFileName(fileValue);
    if (fileName == null) return null;

    if (fileName.startsWith('http://') ||
        fileName.startsWith('https://') ||
        fileName.startsWith('data:') ||
        fileName.startsWith('blob:')) {
      return fileName;
    }

    final encodedFileName = Uri.encodeComponent(fileName);

    return '${PocketBaseService.baseUrl}/api/files/$collectionName/$recordId/$encodedFileName';
  }

  static Future<http.MultipartFile> multipartFromXFile({
    required String fieldName,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();

    return http.MultipartFile.fromBytes(fieldName, bytes, filename: file.name);
  }

  static Future<http.MultipartFile> multipartFromPlatformFile({
    required String fieldName,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;

    if (bytes != null) {
      return http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: file.name,
      );
    }

    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return http.MultipartFile.fromPath(fieldName, path, filename: file.name);
    }

    throw 'Не удалось прочитать файл';
  }

  static bool isImageFile(String value) {
    final lower = value.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  static String fileExtension(String value) {
    final clean = value.split('?').first.split('#').first;
    final index = clean.lastIndexOf('.');

    if (index == -1 || index == clean.length - 1) {
      return 'FILE';
    }

    return clean.substring(index + 1).toUpperCase();
  }

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    }

    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }

    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}
