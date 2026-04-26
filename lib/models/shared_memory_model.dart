import 'package:cloud_firestore/cloud_firestore.dart';

class SharedMemoryModel {
  final String id;
  final String sharedBy;       // sender uid
  final String sharedByName;
  final String sharedByEmail;
  final String eventTitle;
  final String originalMemoryId;
  final String note;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime originalCreatedAt;
  final DateTime sharedAt;
  final String? mood;

  const SharedMemoryModel({
    required this.id,
    required this.sharedBy,
    required this.sharedByName,
    required this.sharedByEmail,
    required this.eventTitle,
    required this.originalMemoryId,
    required this.note,
    required this.mediaUrls,
    required this.mediaTypes,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.originalCreatedAt,
    required this.sharedAt,
    this.mood,
  });

  factory SharedMemoryModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return SharedMemoryModel(
      id: docId,
      sharedBy: data['sharedBy'] ?? '',
      sharedByName: data['sharedByName'] ?? 'Someone',
      sharedByEmail: data['sharedByEmail'] ?? '',
      eventTitle: data['eventTitle'] ?? '',
      originalMemoryId: data['originalMemoryId'] ?? '',
      note: data['note'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      locationName: data['locationName'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      originalCreatedAt:
          (data['originalCreatedAt'] as Timestamp).toDate(),
      sharedAt: (data['sharedAt'] as Timestamp).toDate(),
      mood: data['mood'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sharedBy': sharedBy,
        'sharedByName': sharedByName,
        'sharedByEmail': sharedByEmail,
        'eventTitle': eventTitle,
        'originalMemoryId': originalMemoryId,
        'note': note,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'originalCreatedAt': Timestamp.fromDate(originalCreatedAt),
        'sharedAt': FieldValue.serverTimestamp(),
        if (mood != null) 'mood': mood,
      };

  String? get thumbnailUrl {
    final idx = mediaTypes.indexOf('image');
    return idx >= 0 ? mediaUrls[idx] : null;
  }
}
