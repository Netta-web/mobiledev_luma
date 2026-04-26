import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  User? _user;
  bool  _isLoading = false;
  String? _error;

  User?   get user      => _user;
  bool    get isLoading => _isLoading;
  String? get error     => _error;
  bool    get isLoggedIn => _user != null;

  AuthProvider() {
    _service.authStateChanges.listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      await _service.login(email, password);
      _error = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    try {
      await _service.register(name, email, password);
      _error = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() => _service.signOut();

  Future<void> uploadProfilePhoto(File file) async {
    _setLoading(true);
    try {
      await _service.uploadProfilePhoto(file);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _service.updateDisplayName(name);
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) =>
      _service.sendPasswordReset(email);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':       return 'No account found with that email.';
      case 'wrong-password':       return 'Incorrect password. Try again.';
      case 'email-already-in-use': return 'An account with that email already exists.';
      case 'weak-password':        return 'Password must be at least 6 characters.';
      case 'invalid-email':        return 'Please enter a valid email address.';
      default:                     return 'Something went wrong. Please try again.';
    }
  }
}
