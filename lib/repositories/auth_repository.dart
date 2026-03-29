import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseFirestore firestore,
    required auth.FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _firebaseAuth;

  Stream<auth.User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  Stream<User?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return User.fromMap(data, snapshot.id);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await setPresence(isOnline: true);
  }

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedUsername = normalizeUsername(username);
    auth.UserCredential? credential;

    try {
      credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthFlowException(
          'Unable to create the account right now. Please try again.',
        );
      }

      final userRef = _firestore.collection('users').doc(firebaseUser.uid);
      final usernameRef = _firestore
          .collection('usernames')
          .doc(normalizedUsername);

      await _firestore.runTransaction((transaction) async {
        final usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists) {
          throw const UsernameAlreadyTakenException();
        }

        transaction.set(usernameRef, {
          'uid': firebaseUser.uid,
          'username': normalizedUsername,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'name': name.trim(),
          'username': normalizedUsername,
          'usernameLower': normalizedUsername,
          'email': email.trim(),
          'avatar': null,
          'bio': 'New here and ready to chat.',
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      await firebaseUser.updateDisplayName(name.trim());
      await setPresence(isOnline: true);
    } on UsernameAlreadyTakenException {
      await _cleanupPartiallyCreatedUser(credential?.user);
      rethrow;
    } on FirebaseException {
      await _cleanupPartiallyCreatedUser(credential?.user);
      rethrow;
    } catch (_) {
      await _cleanupPartiallyCreatedUser(credential?.user);
      throw const AuthFlowException(
        'Unable to complete sign up right now. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await setPresence(isOnline: false);
    await _firebaseAuth.signOut();
  }

  Future<void> setPresence({required bool isOnline}) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return;
    }

    await _firestore.collection('users').doc(firebaseUser.uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String normalizeUsername(String input) {
    return input.trim().replaceFirst('@', '').toLowerCase();
  }

  Future<void> _cleanupPartiallyCreatedUser(auth.User? user) async {
    if (user == null) {
      return;
    }

    try {
      await user.delete();
    } catch (_) {
      // Best-effort cleanup. If delete fails, the auth account can still be
      // removed manually from Firebase console.
    }
  }
}

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();

  @override
  String toString() => 'This username is already taken.';
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
