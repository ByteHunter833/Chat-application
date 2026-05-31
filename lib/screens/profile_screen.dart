import 'package:chat_app/widgets/action_button.dart';
import 'package:flutter/cupertino.dart';
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
  final bool isMuted;

  const ProfileScreen({
    super.key,
    this.isMuted = false,
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
    final liveUser = ref.watch(userByIdProvider(userId)).value;
    final presence = ref.watch(userPresenceProvider(userId)).value;
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
        backgroundColor: Colors.transparent,
        elevation: 0,

        iconTheme: IconThemeData(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _buildProfileHeader(
                  context,
                  displayUser: displayUser,
                  statusText: statusText,
                  statusColor: statusColor,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                _buildActionsPanel(context),
                const SizedBox(height: AppTheme.spacingXl),
                _buildInfoSection(context, displayUser),
                const SizedBox(height: AppTheme.spacingXl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required User displayUser,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        children: [
          AvatarWidget(
            imageUrl: displayUser.avatar,
            initials: _getInitials(displayUser.name),
            size: 112,
            isOnline: displayUser.isOnline,
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            displayUser.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: AppTheme.spacingMd),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPanel(BuildContext context) {
    return Row(
      children: [
        ActionButton(
          icon: CupertinoIcons.chat_bubble_fill,
          label: 'Message',
          onTap: () => Navigator.pop(context),
        ),
        ActionButton(
          icon: CupertinoIcons.phone_fill,
          label: 'Call',
          onTap: () => Navigator.pop(context),
        ),
        ActionButton(
          icon: CupertinoIcons.bell_fill,
          label: 'Notify',
          onTap: () => {},
        ),
        ActionButton(
          icon: CupertinoIcons.gift,
          label: 'Gift',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context, User displayUser) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLg,
        vertical: AppTheme.spacingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildInfoRow(context, 'Username', displayUser.handle)],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                label,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.qrcode,
            color: AppTheme.primary,
            size: 21,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final trimmedName = name.trim();
    final parts = trimmedName.split(RegExp(r'\s+'));
    if (trimmedName.isEmpty) {
      return '?';
    }
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmedName.substring(0, 1).toUpperCase();
  }
}
