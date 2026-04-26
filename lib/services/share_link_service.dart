import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/share_link_model.dart';

class ShareLinkService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('public_links');

  Future<String> createLink(ShareLinkModel link) async {
    final doc = await _col.add(link.toFirestore());
    return doc.id;
  }

  Future<ShareLinkModel?> fetchLink(String linkId) async {
    final doc = await _col.doc(linkId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ShareLinkModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> deleteLink(String linkId) => _col.doc(linkId).delete();

  Future<void> setDownloadEnabled(String linkId, bool enabled) =>
      _col.doc(linkId).update({'downloadEnabled': enabled});

  // Single-field query — no composite index required.
  Future<List<ShareLinkModel>> getLinksForMemory(String memoryId) async {
    final snap =
        await _col.where('memoryId', isEqualTo: memoryId).get();
    return snap.docs
        .map((d) => ShareLinkModel.fromFirestore(d.data(), d.id))
        .toList();
  }
}
