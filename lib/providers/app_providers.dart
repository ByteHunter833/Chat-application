import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/app_config.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/storage_repository.dart';

// Auth provider
final firebaseAuthProvider = Provider<auth.FirebaseAuth>((ref) {
  return auth.FirebaseAuth.instance;
});
// FireStore and Realtime Database providers
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final realtimeDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
    realtimeDatabase: ref.watch(realtimeDatabaseProvider),
  );
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    firestore: ref.watch(firestoreProvider),
    realtimeDatabase: ref.watch(realtimeDatabaseProvider),
  );
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final client = AppConfig.hasSupabase ? Supabase.instance.client : null;
  return StorageRepository(client: client);
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref.watch(authRepositoryProvider));
    });

final authStateChangesProvider = StreamProvider<auth.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
});

final currentAppUserProvider = StreamProvider<User?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(null);
  }
  return ref.watch(authRepositoryProvider).watchUser(userId);
});

final userByIdProvider = StreamProvider.family<User?, String>((ref, userId) {
  return ref.watch(authRepositoryProvider).watchUser(userId);
});

final userPresenceProvider = StreamProvider.family<UserPresence?, String>((
  ref,
  userId,
) {
  return ref.watch(authRepositoryProvider).watchPresence(userId);
});

final chatsProvider = StreamProvider<List<Chat>>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) {
    return Stream.value(const <Chat>[]);
  }
  return ref.watch(chatRepositoryProvider).watchChats(currentUserId);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  chatId,
) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});

final chatTypingProvider =
    StreamProvider.family<bool, ({String chatId, String otherUserId})>((
      ref,
      params,
    ) {
      return ref
          .watch(chatRepositoryProvider)
          .watchTypingState(
            chatId: params.chatId,
            otherUserId: params.otherUserId,
          );
    });

final userSearchProvider = FutureProvider.family<List<User>, String>((
  ref,
  query,
) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  return ref
      .watch(chatRepositoryProvider)
      .searchUsersByUsername(query: query, excludeUserId: currentUserId);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._authRepository) : super(const AsyncData(null));

  final AuthRepository _authRepository;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _authRepository.signUp(
        name: name,
        username: username,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _authRepository.signOut());
  }
}
