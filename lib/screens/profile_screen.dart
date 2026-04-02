import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/avatar_widget.dart';

class ProfileScreen extends ConsumerWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final String? userHandle;
  final bool isOnline;
  final DateTime? lastSeen;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.userHandle,
    required this.isOnline,
    this.lastSeen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveUser = ref.watch(userByIdProvider(userId)).valueOrNull;
    final presence = ref.watch(userPresenceProvider(userId)).valueOrNull;
    final displayUser =
        (liveUser ??
                User(
                  id: userId,
                  name: userName,
                  username:
                      userHandle?.replaceFirst('@', '') ??
                      userName.replaceAll(' ', '').toLowerCase(),
                  avatar: userAvatar,
                  isOnline: isOnline,
                  lastSeen: lastSeen,
                ))
            .applyPresence(presence);
    final statusText = Formatters.formatPresenceStatus(
      isOnline: displayUser.isOnline,
      lastSeen: displayUser.lastSeen,
    );
    final statusColor = displayUser.isOnline
        ? AppTheme.success
        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            // Avatar Section
            Center(
              child: Column(
                children: [
                  AvatarWidget(
                    imageUrl: displayUser.avatar,
                    initials: _getInitials(displayUser.name),
                    size: 120,
                    isOnline: displayUser.isOnline,
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  Text(
                    displayUser.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (displayUser.handle.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXs),
                    Text(
                      displayUser.handle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: AppTheme.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.message,
                    label: 'Message',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: _buildActionButton(
                    context,
                    icon: Icons.call,
                    label: 'Call',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call initiated')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXl),
            // Info Section
            _buildInfoSection(context, displayUser),
            const SizedBox(height: AppTheme.spacingXl),
            // Actions
            _buildMenuButton(
              context,
              icon: Icons.clear,
              label: 'Block Contact',
              isDanger: true,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            _buildMenuButton(
              context,
              icon: Icons.delete_outline,
              label: 'Delete Chat',
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingMd,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppTheme.spacingSm),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, User displayUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: isDark ? AppTheme.darkShadow : AppTheme.lightShadow,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          _buildInfoRow(context, 'User ID', userId),
          const Divider(height: 24),
          _buildInfoRow(context, 'Username', displayUser.handle),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDanger,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDanger ? AppTheme.error : AppTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: isDark ? AppTheme.darkShadow : AppTheme.lightShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$label feature')));
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }
}
