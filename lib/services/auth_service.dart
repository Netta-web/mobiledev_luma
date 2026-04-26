import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    // Store profile in Firestore so we can extend it later
    await _db.collection('users').doc(cred.user!.uid).set({
      'displayName': name,
      'email': email,
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return cred;
  }

  Future<UserCredential> login(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> uploadProfilePhoto(File file) async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final url = await StorageService().uploadAvatar(file, uid);
    await currentUser?.updatePhotoURL(url);
    await _db.collection('users').doc(uid).update({'photoUrl': url});
    return url;
  }

  Future<void> updateDisplayName(String name) async {
    await currentUser?.updateDisplayName(name);
    final uid = currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({'displayName': name});
    }
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
