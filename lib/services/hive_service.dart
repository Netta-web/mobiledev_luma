import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event_model.dart';
import '../models/memory_entry_model.dart';

// Hive is used as an offline cache — events and memories are written here
// every time we receive fresh data from Firestore, so the app works offline.

class HiveService {
  static const _eventsBox   = 'events_cache';
  static const _memoriesBox = 'memories_cache';

  static Future<void> openBoxes() async {
    await Hive.openBox(_eventsBox);
    await Hive.openBox(_memoriesBox);
  }

  // ── Events ─────────────────────────────────────────────────

  static Box get _events => Hive.box(_eventsBox);

  static Future<void> cacheEvents(List<EventModel> events) async {
    final map = {for (final e in events) e.id: jsonEncode(e.toJson())};
    await _events.putAll(map);
    // Remove stale keys that are no longer in Firestore
    final stale = _events.keys
        .cast<String>()
        .where((k) => !map.containsKey(k))
        .toList();
    await _events.deleteAll(stale);
  }

  static List<EventModel> getCachedEvents() {
    return _events.values
        .cast<String>()
        .map((raw) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          // Hive cache stores ISO strings; convert back to Timestamps for model
          return _eventFromCache(data);
        })
        .toList();
  }

  // ── Memories ───────────────────────────────────────────────

  static Box get _memories => Hive.box(_memoriesBox);

  static String _memoryKey(String eventId, String memId) => '$eventId|$memId';

  static Future<void> cacheMemories(
      String eventId, List<MemoryEntryModel> entries) async {
    final map = {
      for (final e in entries)
        _memoryKey(eventId, e.id): jsonEncode(e.toJson())
    };
    await _memories.putAll(map);
    final staleKeys = _memories.keys
        .cast<String>()
        .where((k) => k.startsWith('$eventId|') && !map.containsKey(k))
        .toList();
    await _memories.deleteAll(staleKeys);
  }

  static List<MemoryEntryModel> getCachedMemories(String eventId) {
    return _memories.keys
        .cast<String>()
        .where((k) => k.startsWith('$eventId|'))
        .map((k) {
          final raw  = _memories.get(k) as String;
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final id   = k.split('|').last;
          return _memoryFromCache(data, id);
        })
        .toList();
  }

  // ── Private helpers ────────────────────────────────────────
  // Firestore Timestamps are serialised to ISO strings in Hive.

  static EventModel _eventFromCache(Map<String, dynamic> d) {
    return EventModel(
      id: d['id'] ?? '',
      userId: d['userId'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'other',
      startDate: DateTime.parse(d['startDate']),
      endDate: d['endDate'] != null ? DateTime.parse(d['endDate']) : null,
      memoryCount: d['memoryCount'] ?? 0,
      coverImageUrl: d['coverImageUrl'],
      createdAt: DateTime.parse(d['createdAt']),
    );
  }

  static MemoryEntryModel _memoryFromCache(Map<String, dynamic> d, String id) {
    return MemoryEntryModel(
      id: id,
      eventId: d['eventId'] ?? '',
      userId: d['userId'] ?? '',
      note: d['note'] ?? '',
      mediaUrls: List<String>.from(d['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(d['mediaTypes'] ?? []),
      voiceNoteUrl: d['voiceNoteUrl'],
      latitude: (d['latitude'] ?? 0.0).toDouble(),
      longitude: (d['longitude'] ?? 0.0).toDouble(),
      locationName: d['locationName'] ?? '',
      createdAt: DateTime.parse(d['createdAt']),
      sharedWith: List<String>.from(d['sharedWith'] ?? []),
    );
  }
}
