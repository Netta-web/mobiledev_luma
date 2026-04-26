import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/memory_entry_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';

class MemoryProvider extends ChangeNotifier {
  final _firestoreService = FirestoreService();
  final _storageService   = StorageService();
  final _locationService  = LocationService();

  final Map<String, List<MemoryEntryModel>> _memoriesByEvent = {};
  final Map<String, StreamSubscription<List<MemoryEntryModel>>> _subs = {};

  bool    _isLoading = false;
  String? _error;

  bool    get isLoading => _isLoading;
  String? get error     => _error;

  List<MemoryEntryModel> memoriesForEvent(String eventId) =>
      _memoriesByEvent[eventId] ?? [];

  void startListeningToEvent(String uid, String eventId) {
    if (_subs.containsKey(eventId)) return; // already subscribed

    // Show cache immediately
    _memoriesByEvent[eventId] = HiveService.getCachedMemories(eventId);
    notifyListeners();

    _subs[eventId] = _firestoreService.watchMemories(uid, eventId).listen(
      (entries) {
        _memoriesByEvent[eventId] = entries;
        HiveService.cacheMemories(eventId, entries);
        notifyListeners();
      },
      onError: (_) {
        _error = 'Could not load memories. Showing cached data.';
        notifyListeners();
      },
    );
  }

  void stopListeningToEvent(String eventId) {
    _subs[eventId]?.cancel();
    _subs.remove(eventId);
    _memoriesByEvent.remove(eventId);
  }

  void stopAll() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _memoriesByEvent.clear();
  }

  Future<LocationResult?> fetchLocation() => _locationService.getCurrentLocation();

  // Creates a memory entry, uploading media files first.
  Future<bool> createMemory({
    required String uid,
    required String eventId,
    required String note,
    required List<File> mediaFiles,
    required List<String> mediaTypes,
    required double latitude,
    required double longitude,
    required String locationName,
    List<String> sharedWith = const [],
    String? mood,
  }) async {
    _setLoading(true);
    try {
      final uploaded = await _storageService.uploadMediaFiles(
          mediaFiles, mediaTypes, uid, eventId);

      final entry = MemoryEntryModel(
        id: '',
        eventId: eventId,
        userId: uid,
        note: note,
        mediaUrls: uploaded.urls,
        mediaTypes: uploaded.types,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        createdAt: DateTime.now(),
        sharedWith: sharedWith,
        mood: mood,
      );

      await _firestoreService.createMemory(uid, eventId, entry);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteMemory(
      String uid, String eventId, MemoryEntryModel entry) async {
    try {
      // Delete media from Storage
      for (final url in entry.mediaUrls) {
        await _storageService.deleteFile(url);
      }
      await _firestoreService.deleteMemory(uid, eventId, entry.id);
      return true;
    } catch (e) {
      _error = 'Failed to delete memory.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}
