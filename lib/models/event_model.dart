import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category; // academic | travel | personal | work | other
  final DateTime startDate;
  final DateTime? endDate;
  final int memoryCount;
  final String? coverImageUrl;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const EventModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.startDate,
    this.endDate,
    this.memoryCount = 0,
    this.coverImageUrl,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory EventModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return EventModel(
      id: docId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'other',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      memoryCount: data['memoryCount'] ?? 0,
      coverImageUrl: data['coverImageUrl'],
      locationName: data['locationName'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'description': description,
        'category': category,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'memoryCount': memoryCount,
        'coverImageUrl': coverImageUrl,
        if (locationName != null) 'locationName': locationName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  // Hive / JSON cache — uses ISO strings instead of Firestore Timestamps
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'category': category,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'memoryCount': memoryCount,
        'coverImageUrl': coverImageUrl,
        if (locationName != null) 'locationName': locationName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'createdAt': createdAt.toIso8601String(),
      };

  EventModel copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? memoryCount,
    String? coverImageUrl,
    String? locationName,
    double? latitude,
    double? longitude,
  }) {
    return EventModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      memoryCount: memoryCount ?? this.memoryCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt,
    );
  }
}
