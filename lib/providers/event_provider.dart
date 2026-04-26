import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';

class EventProvider extends ChangeNotifier {
  final _service = FirestoreService();

  List<EventModel> _events    = [];
  bool             _isLoading = false;
  String?          _error;
  StreamSubscription<List<EventModel>>? _sub;

  List<EventModel> get events    => _events;
  bool             get isLoading => _isLoading;
  String?          get error     => _error;

  // Call once after login to start listening to Firestore.
  void startListening(String uid) {
    _isLoading = true;
    notifyListeners();

    // Show cached events immediately while Firestore loads
    _events = HiveService.getCachedEvents();
    notifyListeners();

    _sub = _service.watchEvents(uid).listen(
      (events) {
        _events    = events;
        _isLoading = false;
        _error     = null;
        HiveService.cacheEvents(events);
        notifyListeners();
      },
      onError: (e) {
        _error     = 'Could not load events. Showing cached data.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _events = [];
  }

  Future<EventModel?> createEvent(String uid, EventModel event) async {
    try {
      final created = await _service.createEvent(uid, event);
      return created;
    } catch (e) {
      _error = 'Failed to create event.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEvent(String uid, EventModel event) async {
    try {
      await _service.updateEvent(uid, event);
      return true;
    } catch (e) {
      _error = 'Failed to update event.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(String uid, String eventId) async {
    try {
      await _service.deleteEvent(uid, eventId);
      return true;
    } catch (e) {
      _error = 'Failed to delete event.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
