import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
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

            return const ChatListScreen();
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
