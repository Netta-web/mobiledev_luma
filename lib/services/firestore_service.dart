import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../models/memory_entry_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Events ─────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _eventsCol(String uid) =>
      _db.collection('users').doc(uid).collection('events');

  Stream<List<EventModel>> watchEvents(String uid) {
    return _eventsCol(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => EventModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<EventModel> createEvent(String uid, EventModel event) async {
    final ref = await _eventsCol(uid).add(event.toFirestore());
    final snap = await ref.get();
    return EventModel.fromFirestore(snap.data()!, snap.id);
  }

  Future<void> updateEvent(String uid, EventModel event) {
    return _eventsCol(uid).doc(event.id).update(event.toFirestore());
  }

  Future<void> deleteEvent(String uid, String eventId) async {
    // Delete all child memories first
    final memories = await _memoriesCol(uid, eventId).get();
    for (final doc in memories.docs) {
      await doc.reference.delete();
    }
    await _eventsCol(uid).doc(eventId).delete();
  }

  // ── Memory Entries ─────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _memoriesCol(
          String uid, String eventId) =>
      _eventsCol(uid).doc(eventId).collection('memories');

  Stream<List<MemoryEntryModel>> watchMemories(String uid, String eventId) {
    return _memoriesCol(uid, eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MemoryEntryModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<MemoryEntryModel> createMemory(
      String uid, String eventId, MemoryEntryModel entry) async {
    final ref = await _memoriesCol(uid, eventId).add(entry.toFirestore());
    // Increment event memory count
    await _eventsCol(uid)
        .doc(eventId)
        .update({'memoryCount': FieldValue.increment(1)});
    final snap = await ref.get();
    return MemoryEntryModel.fromFirestore(snap.data()!, snap.id);
  }

  Future<void> updateMemory(
      String uid, String eventId, MemoryEntryModel entry) {
    return _memoriesCol(uid, eventId)
        .doc(entry.id)
        .update(entry.toFirestore());
  }

  Future<void> deleteMemory(
      String uid, String eventId, String memoryId) async {
    await _memoriesCol(uid, eventId).doc(memoryId).delete();
    await _eventsCol(uid)
        .doc(eventId)
        .update({'memoryCount': FieldValue.increment(-1)});
  }
}
