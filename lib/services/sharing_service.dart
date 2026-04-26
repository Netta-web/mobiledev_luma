import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memory_entry_model.dart';
import '../models/event_model.dart';
import '../models/shared_memory_model.dart';

class SharingService {
  final _db = FirebaseFirestore.instance;

  // Each recipient has a subcollection keyed by their email address.
  // This lets the app query "what was shared with me?" without a
  // collection-group index on all users.
  CollectionReference<Map<String, dynamic>> _recipientCol(String email) =>
      _db.collection('shared_memories').doc(email).collection('items');

  // ── Share ──────────────────────────────────────────────────

  Future<String> shareMemory({
    required String fromUid,
    required String fromName,
    required String fromEmail,
    required MemoryEntryModel memory,
    required EventModel event,
    required String recipientEmail,
  }) async {
    final doc = await _recipientCol(recipientEmail).add(
      SharedMemoryModel(
        id: '',
        sharedBy: fromUid,
        sharedByName: fromName,
        sharedByEmail: fromEmail,
        eventTitle: event.title,
        originalMemoryId: memory.id,
        note: memory.note,
        mediaUrls: memory.mediaUrls,
        mediaTypes: memory.mediaTypes,
        locationName: memory.locationName,
        latitude: memory.latitude,
        longitude: memory.longitude,
        originalCreatedAt: memory.createdAt,
        sharedAt: DateTime.now(),
        mood: memory.mood,
      ).toFirestore(),
    );
    return doc.id;
  }

  // ── Revoke ─────────────────────────────────────────────────

  Future<void> revokeShare({
    required String recipientEmail,
    required String shareDocId,
  }) {
    return _recipientCol(recipientEmail).doc(shareDocId).delete();
  }

  // Revoke all shares of a specific original memory for one recipient.
  Future<void> revokeShareForMemory({
    required String recipientEmail,
    required String originalMemoryId,
  }) async {
    final snap = await _recipientCol(recipientEmail)
        .where('originalMemoryId', isEqualTo: originalMemoryId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // ── Watch received ─────────────────────────────────────────

  Stream<List<SharedMemoryModel>> watchReceivedMemories(String email) {
    return _recipientCol(email)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SharedMemoryModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  // ── Check if already shared ────────────────────────────────

  Future<bool> isAlreadySharedWith({
    required String recipientEmail,
    required String originalMemoryId,
  }) async {
    final snap = await _recipientCol(recipientEmail)
        .where('originalMemoryId', isEqualTo: originalMemoryId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}
