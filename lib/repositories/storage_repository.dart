import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class StorageRepository {
  StorageRepository({required SupabaseClient? client}) : _client = client;

  static const String bucketName = 'chat-media';
  static const int maxUploadBytes = 20 * 1024 * 1024;

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  Future<UploadedMedia> uploadChatMedia({
    required PlatformFile file,
    required String chatId,
    required String senderId,
  }) async {
    if (_client == null) {
      throw const StorageNotConfiguredException();
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const StorageUploadException(
        'Selected file is empty or unavailable.',
      );
    }

    if (bytes.length > maxUploadBytes) {
      throw const StorageUploadException(
        'File is too large. Please keep attachments under 20 MB.',
      );
    }

    final sanitizedName = _sanitizeFileName(file.name);
    final extension = _extractExtension(sanitizedName);
    final storagePath =
        '$chatId/$senderId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    final mimeType = _detectMimeType(file.name);

    await _client.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final publicUrl = _client.storage
        .from(bucketName)
        .getPublicUrl(storagePath);
    return UploadedMedia(
      url: publicUrl,
      fileName: file.name,
      mimeType: mimeType,
      fileSize: bytes.length,
      messageType: _messageTypeForFile(
        fileName: file.name,
        extension: extension,
        mimeType: mimeType,
      ),
    );
  }

  Future<String> uploadGroupAvatar({
    required PlatformFile file,
    required String ownerId,
  }) async {
    if (_client == null) {
      throw const StorageNotConfiguredException();
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const StorageUploadException(
        'Selected image is empty or unavailable.',
      );
    }

    if (bytes.length > maxUploadBytes) {
      throw const StorageUploadException(
        'Image is too large. Please keep group photos under 20 MB.',
      );
    }

    final sanitizedName = _sanitizeFileName(file.name);
    final mimeType = _detectMimeType(file.name);
    if (!mimeType.startsWith('image/')) {
      throw const StorageUploadException('Please choose an image file.');
    }

    final storagePath =
        'group-avatars/$ownerId/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
    await _client.storage
        .from(bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    return _client.storage.from(bucketName).getPublicUrl(storagePath);
  }

  String _sanitizeFileName(String input) {
    final trimmed = input.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty ? 'attachment' : sanitized;
  }

  String _extractExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _detectMimeType(String fileName) {
    final extension = _extractExtension(fileName);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  MessageType _messageTypeForFile({
    required String fileName,
    required String extension,
    required String mimeType,
  }) {
    if (mimeType.startsWith('image/')) {
      return MessageType.image;
    }
    if (mimeType.startsWith('video/')) {
      return MessageType.video;
    }

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return MessageType.image;
      case 'mp4':
      case 'mov':
      case 'm4v':
        return MessageType.video;
      default:
        return MessageType.file;
    }
  }
}

class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.messageType,
  });

  final String url;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final MessageType messageType;
}

class StorageNotConfiguredException implements Exception {
  const StorageNotConfiguredException();

  @override
  String toString() {
    return 'Supabase Storage is not configured. Pass SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define.';
  }
}

class StorageUploadException implements Exception {
  const StorageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
