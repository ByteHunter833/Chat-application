import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../utils/push_notification_service.dart';
import 'auth_screen.dart';
import 'chat_list_screen.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (firebaseUser) {
        if (firebaseUser == null) {
          return const AuthScreen();
        }

        final currentUser = ref.watch(currentAppUserProvider);
        return currentUser.when(
          data: (appUser) {
            if (appUser == null) {
              return const _AppLoadingState(
                title: 'Preparing your profile',
                subtitle: 'Just a moment while we connect your chat data.',
              );
            }

            return _SessionInitializer(
              currentUser: appUser,
              child: const ChatListScreen(),
            );
          },
          loading: () => const _AppLoadingState(
            title: 'Loading chats',
            subtitle: 'Syncing your inbox and contacts.',
          ),
          error: (error, stackTrace) => _AppErrorState(
            title: 'Unable to load your profile',
            subtitle: error.toString(),
            onRetry: () => ref.invalidate(currentAppUserProvider),
          ),
        );
      },
      loading: () => const _AppLoadingState(
        title: 'Connecting to Firebase',
        subtitle: 'Checking your session and restoring the app.',
      ),
      error: (error, stackTrace) => _AppErrorState(
        title: 'Firebase connection failed',
        subtitle: error.toString(),
        onRetry: () {
          ref.invalidate(authStateChangesProvider);
          ref.invalidate(currentAppUserProvider);
        },
      ),
    );
  }
}

class _SessionInitializer extends ConsumerStatefulWidget {
  const _SessionInitializer({required this.currentUser, required this.child});

  final User currentUser;
  final Widget child;

  @override
  ConsumerState<_SessionInitializer> createState() =>
      _SessionInitializerState();
}

class _SessionInitializerState extends ConsumerState<_SessionInitializer>
    with WidgetsBindingObserver {
  late final AuthRepository _authRepository;
  bool? _isOnline;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _authRepository = ref.read(authRepositoryProvider);
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _SessionInitializer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _isOnline = null;
      _initialize();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      PushNotificationService.clearSession(userId: widget.currentUser.id),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_setPresence(isOnline: true));
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_setPresence(isOnline: false));
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _initialize() async {
    await _authRepository.bindPresence(widget.currentUser.id);
    if (!mounted || _isDisposed) {
      return;
    }

    await _setPresence(isOnline: true);
    if (!mounted || _isDisposed) {
      return;
    }

    await PushNotificationService.syncUserSession(widget.currentUser);
  }

  Future<void> _setPresence({required bool isOnline}) async {
    if (!mounted || _isDisposed) {
      return;
    }

    if (_isOnline == isOnline) {
      return;
    }

    final previousValue = _isOnline;
    _isOnline = isOnline;
    try {
      await _authRepository.setPresence(isOnline: isOnline);
    } catch (_) {
      _isOnline = previousValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AppLoadingState extends StatelessWidget {
  const _AppLoadingState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppTheme.spacingXl),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppErrorState extends StatelessWidget {
  const _AppErrorState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.error,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingXl),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
