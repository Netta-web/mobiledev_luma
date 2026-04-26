import 'package:cloud_firestore/cloud_firestore.dart';

class ShareLinkModel {
  final String id;
  final String ownerId;
  final String ownerName;
  final String memoryId;
  final String eventTitle;
  final String note;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final String locationName;
  final String? mood;
  final bool downloadEnabled;
  final DateTime createdAt;

  const ShareLinkModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.memoryId,
    required this.eventTitle,
    required this.note,
    required this.mediaUrls,
    required this.mediaTypes,
    required this.locationName,
    this.mood,
    required this.downloadEnabled,
    required this.createdAt,
  });

  factory ShareLinkModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    return ShareLinkModel(
      id: docId,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'] ?? '',
      memoryId: data['memoryId'] ?? '',
      eventTitle: data['eventTitle'] ?? '',
      note: data['note'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
      locationName: data['locationName'] ?? '',
      mood: data['mood'] as String?,
      downloadEnabled: data['downloadEnabled'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'ownerId': ownerId,
        'ownerName': ownerName,
        'memoryId': memoryId,
        'eventTitle': eventTitle,
        'note': note,
        'mediaUrls': mediaUrls,
        'mediaTypes': mediaTypes,
        'locationName': locationName,
        if (mood != null) 'mood': mood,
        'downloadEnabled': downloadEnabled,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  ShareLinkModel copyWithDownload(bool enabled) => ShareLinkModel(
        id: id,
        ownerId: ownerId,
        ownerName: ownerName,
        memoryId: memoryId,
        eventTitle: eventTitle,
        note: note,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        locationName: locationName,
        mood: mood,
        downloadEnabled: enabled,
        createdAt: createdAt,
      );
}
