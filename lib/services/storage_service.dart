import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';

class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;
  final _uuid = const Uuid();

  /// Upload one file to a Supabase Storage bucket.
  /// Returns the public URL of the uploaded object.
  Future<String> uploadFile(
    File file,
    String storagePath,
    String bucket,
  ) async {
    final ext   = storagePath.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();

    await _client.storage.from(bucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: _contentType(ext)),
    );

    return _client.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// Upload all media files in parallel.
  /// Returns parallel lists of public URLs and their types.
  Future<({List<String> urls, List<String> types})> uploadMediaFiles(
    List<File> files,
    List<String> types,
    String uid,
    String eventId,
  ) async {
    if (files.isEmpty) return (urls: <String>[], types: <String>[]);

    Future<String> uploadOne(int i) {
      final ext  = files[i].path.split('.').last.toLowerCase();
      final path = '$uid/$eventId/${_uuid.v4()}.$ext';
      return uploadFile(files[i], path, SupabaseConfig.memoriesBucket);
    }

    final urls = await Future.wait(List.generate(files.length, uploadOne));
    return (urls: urls, types: types);
  }

  /// Upload a profile photo, replacing any existing avatar for this user.
  Future<String> uploadAvatar(File file, String uid) async {
    final bytes = await file.readAsBytes();
    const path  = 'avatar.jpg'; // stored under uid/ folder

    await _client.storage
        .from(SupabaseConfig.avatarsBucket)
        .uploadBinary(
          '$uid/$path',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true, // overwrite existing
          ),
        );

    return _client.storage
        .from(SupabaseConfig.avatarsBucket)
        .getPublicUrl('$uid/$path');
  }

  /// Download a file by its Supabase public URL and return its bytes.
  Future<Uint8List> downloadFile(String downloadUrl) async {
    final uri      = Uri.parse(downloadUrl);
    final segments = uri.pathSegments;
    final pubIndex = segments.indexOf('public');
    if (pubIndex < 0 || pubIndex + 2 > segments.length) {
      throw Exception('Invalid Supabase URL: $downloadUrl');
    }
    final bucket   = segments[pubIndex + 1];
    final filePath = segments.sublist(pubIndex + 2).join('/');
    return _client.storage.from(bucket).download(filePath);
  }

  /// Delete a file using its Supabase public URL.
  /// Silently ignores errors (e.g. file already deleted).
  Future<void> deleteFile(String downloadUrl) async {
    try {
      // Supabase public URL format:
      // https://{ref}.supabase.co/storage/v1/object/public/{bucket}/{path}
      final uri      = Uri.parse(downloadUrl);
      final segments = uri.pathSegments;
      final pubIndex = segments.indexOf('public');
      if (pubIndex < 0 || pubIndex + 2 > segments.length) return;
      final bucket   = segments[pubIndex + 1];
      final filePath = segments.sublist(pubIndex + 2).join('/');
      await _client.storage.from(bucket).remove([filePath]);
    } catch (_) {
      // File may already be gone; safe to ignore.
    }
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'avi':  return 'video/x-msvideo';
      case 'mkv':  return 'video/x-matroska';
      case '3gp':  return 'video/3gpp';
      case 'm4v':  return 'video/x-m4v';
      default:     return 'application/octet-stream';
    }
  }
}
