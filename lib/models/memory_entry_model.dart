import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryEntryModel {
  final String id;
  final String eventId;
  final String userId;
  final String note;
  final List<String> mediaUrls;  // photos / videos in Firebase Storage
  final List<String> mediaTypes; // "image" or "video", parallel to mediaUrls
  final String? voiceNoteUrl;
  final double latitude;
  final double longitude;
  final String locationName;
  final DateTime createdAt;
  final List<String> sharedWith; // contact phone numbers
  final String? mood;            // optional mood tag e.g. "Happy"

  const MemoryEntryModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.note,
    required this.mediaUrls,
    required this.mediaTypes,
    this.voiceNoteUrl,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.createdAt,
    required this.sharedWith,
    this.mood,
  });

  factory MemoryEntryModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return MemoryEntryModel(
      id: docId,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      note: data['note'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      voiceNoteUrl: data['voiceNoteUrl'],
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      locationName: data['locationName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      mood: data['mood'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'eventId': eventId,
        'userId': userId,
        'note': note,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'voiceNoteUrl': voiceNoteUrl,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'createdAt': Timestamp.fromDate(createdAt),
        'sharedWith': sharedWith,
        if (mood != null) 'mood': mood,
      };

  // Hive / JSON cache — uses ISO strings instead of Firestore Timestamps
  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'userId': userId,
        'note': note,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'voiceNoteUrl': voiceNoteUrl,
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'createdAt': createdAt.toIso8601String(),
        'sharedWith': sharedWith,
        if (mood != null) 'mood': mood,
      };

  // Convenience: first image URL for thumbnail display
  String? get thumbnailUrl {
    final idx = mediaTypes.indexOf('image');
    return idx >= 0 ? mediaUrls[idx] : null;
  }

  bool get hasMedia => mediaUrls.isNotEmpty;
}
