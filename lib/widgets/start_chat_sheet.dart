import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'avatar_widget.dart';

class StartChatSheet extends ConsumerStatefulWidget {
  const StartChatSheet({super.key});

  @override
  ConsumerState<StartChatSheet> createState() => _StartChatSheetState();
}

class _StartChatSheetState extends ConsumerState<StartChatSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _isCreatingChat = false;

  String get _query => _searchController.text.trim().replaceFirst('@', '');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChange)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    setState(() {});
  }

  Future<void> _openChat(User targetUser) async {
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isCreatingChat = true;
    });

    try {
      final chat = await ref
          .read(chatRepositoryProvider)
          .createOrGetDirectChat(
            currentUser: currentUser,
            otherUser: targetUser,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(chat);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start chat: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingChat = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultsAsync = ref.watch(userSearchProvider(_query));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          top: AppTheme.spacingLg,
          bottom: AppTheme.spacingLg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              'Start new chat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              'Find people by their unique @username. Only registered app users appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingLg),
            TextField(
              controller: _searchController,
              enabled: !_isCreatingChat,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'Search username',
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            SizedBox(
              height: 360,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildResults(resultsAsync, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AsyncValue<List<User>> resultsAsync, bool isDark) {
    if (_query.isEmpty) {
      return _InfoBox(
        key: const ValueKey('idle'),
        icon: Icons.manage_search_rounded,
        title: 'Search by handle',
        subtitle:
            'Type something like @alex, @sarah_01, or @product_team to find people inside the app.',
      );
    }

    return resultsAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return _InfoBox(
            key: const ValueKey('empty'),
            icon: Icons.person_search_outlined,
            title: 'No user found',
            subtitle:
                'There is no registered account with a matching username yet.',
          );
        }

        return ListView.separated(
          key: const ValueKey('results'),
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTheme.spacingSm),
          itemBuilder: (context, index) {
            final user = users[index];

            return Material(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: ListTile(
                leading: AvatarWidget(
                  imageUrl: user.avatar,
                  initials: _getInitials(user.name),
                  isOnline: user.isOnline,
                ),
                title: Text(user.name),
                subtitle: Text(user.handle),
                trailing: _isCreatingChat
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _isCreatingChat ? null : () => _openChat(user),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _InfoBox(
        key: const ValueKey('error'),
        icon: Icons.error_outline_rounded,
        title: 'Search failed',
        subtitle: error.toString(),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primary, size: 32),
            const SizedBox(height: AppTheme.spacingMd),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
