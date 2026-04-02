import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';

import '../models/models.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseFirestore firestore,
    required auth.FirebaseAuth firebaseAuth,
    required FirebaseDatabase realtimeDatabase,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth,
       _realtimeDatabase = realtimeDatabase;

  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth _firebaseAuth;
  final FirebaseDatabase _realtimeDatabase;
  StreamSubscription<DatabaseEvent>? _presenceConnectionSubscription;
  String? _boundPresenceUserId;

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
    await _clearPresenceBinding();
    await _firebaseAuth.signOut();
  }

  Future<void> setPresence({required bool isOnline}) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return;
    }

    final statusRef = _realtimeDatabase.ref('status/${firebaseUser.uid}');
    final payload = <String, Object?>{
      'state': isOnline ? 'online' : 'offline',
      'last_changed': ServerValue.timestamp,
    };

    await statusRef.set(payload);
    if (isOnline) {
      await statusRef.onDisconnect().set({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });
    } else {
      await statusRef.onDisconnect().cancel();
    }

    await _firestore.collection('users').doc(firebaseUser.uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<UserPresence?> watchPresence(String uid) {
    return _realtimeDatabase.ref('status/$uid').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map<Object?, Object?>) {
        return null;
      }
      return UserPresence.fromMap(raw);
    });
  }

  Future<void> bindPresence(String uid) async {
    if (_boundPresenceUserId == uid) {
      return;
    }

    await _clearPresenceBinding();
    _boundPresenceUserId = uid;

    final connectionRef = _realtimeDatabase.ref('.info/connected');
    final statusRef = _realtimeDatabase.ref('status/$uid');
    _presenceConnectionSubscription = connectionRef.onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) {
        return;
      }

      unawaited(
        statusRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        }),
      );
      unawaited(
        statusRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        }),
      );
    });
  }

  Future<void> _clearPresenceBinding() async {
    _boundPresenceUserId = null;
    await _presenceConnectionSubscription?.cancel();
    _presenceConnectionSubscription = null;
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
