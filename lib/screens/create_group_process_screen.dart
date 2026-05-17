import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';
import 'chat_detail_screen.dart';

class CreateGroupProcessScreen extends ConsumerStatefulWidget {
  const CreateGroupProcessScreen({super.key});

  @override
  ConsumerState<CreateGroupProcessScreen> createState() =>
      _CreateGroupProcessScreenState();
}

class _CreateGroupProcessScreenState
    extends ConsumerState<CreateGroupProcessScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final Map<String, User> _selectedUsers = <String, User>{};
  PlatformFile? _avatarFile;
  Uint8List? _avatarBytes;
  bool _isDetailsStep = false;
  bool _isCreatingGroup = false;

  String get _query => _searchController.text.trim().replaceFirst('@', '');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_rebuild);
    _nameController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_rebuild)
      ..dispose();
    _nameController
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  void _rebuild() {
    setState(() {});
  }

  void _toggleUser(User user) {
    setState(() {
      if (_selectedUsers.containsKey(user.id)) {
        _selectedUsers.remove(user.id);
      } else {
        _selectedUsers[user.id] = user;
      }
    });
  }

  void _goToDetailsStep() {
    if (_selectedUsers.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isDetailsStep = true;
    });
  }

  void _goBackStep() {
    if (!_isDetailsStep) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isDetailsStep = false;
    });
  }

  Future<void> _pickGroupAvatar() async {
    if (_isCreatingGroup) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.image,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _avatarFile = picked.files.single;
      _avatarBytes = picked.files.single.bytes;
    });
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser == null ||
        groupName.isEmpty ||
        _selectedUsers.isEmpty ||
        _isCreatingGroup) {
      return;
    }

    setState(() {
      _isCreatingGroup = true;
    });

    try {
      String? avatarUrl;
      final avatarFile = _avatarFile;
      if (avatarFile != null) {
        avatarUrl = await ref
            .read(storageRepositoryProvider)
            .uploadGroupAvatar(file: avatarFile, ownerId: currentUser.id);
      }

      final chat = await ref
          .read(chatRepositoryProvider)
          .createGroupChat(
            currentUser: currentUser,
            name: groupName,
            members: _selectedUsers.values.toList(),
            avatarUrl: avatarUrl,
          );
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to create group: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingGroup = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoNext = _selectedUsers.isNotEmpty;
    final canCreate =
        _nameController.text.trim().isNotEmpty && _selectedUsers.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isCreatingGroup ? null : _goBackStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isDetailsStep ? 'New Group' : 'Add Members'),
            Text(
              _selectedUsers.isEmpty
                  ? 'Select at least 1 contact'
                  : '${_selectedUsers.length} selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isDetailsStep
            ? _buildDetailsStep(context, isDark)
            : _buildMembersStep(context, isDark),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'group_process_action',
        backgroundColor: _isDetailsStep
            ? (canCreate ? AppTheme.primary : AppTheme.lightTextSecondary)
            : (canGoNext ? AppTheme.primary : AppTheme.lightTextSecondary),
        onPressed: _isCreatingGroup
            ? null
            : _isDetailsStep
            ? (canCreate ? _createGroup : null)
            : (canGoNext ? _goToDetailsStep : null),
        child: _isCreatingGroup
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                _isDetailsStep
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.arrow_right,
                color: Colors.white,
              ),
      ),
    );
  }

  Widget _buildMembersStep(BuildContext context, bool isDark) {
    final resultsAsync = ref.watch(userSearchProvider(_query));

    return Column(
      key: const ValueKey('members-step'),
      children: [
        _SelectedMembersStrip(
          selectedUsers: _selectedUsers.values.toList(),
          onRemove: _toggleUser,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingLg,
            AppTheme.spacingSm,
            AppTheme.spacingLg,
            AppTheme.spacingMd,
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
              prefixText: '@',
              hintText: 'Search username',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
        ),
        Expanded(child: _buildSearchResults(resultsAsync, isDark)),
      ],
    );
  }

  Widget _buildSearchResults(AsyncValue<List<User>> resultsAsync, bool isDark) {
    if (_query.isEmpty) {
      return const _GroupInfoState(
        icon: CupertinoIcons.person_crop_circle_badge_plus,
        title: 'Add people',
        subtitle: 'Search registered app users by their @username.',
      );
    }

    return resultsAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const _GroupInfoState(
            icon: CupertinoIcons.person_2,
            title: 'No users found',
            subtitle: 'Try another username or check the spelling.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: users.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 88,
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            final isSelected = _selectedUsers.containsKey(user.id);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: AppTheme.spacingXs,
              ),
              leading: AvatarWidget(
                imageUrl: user.avatar,
                initials: _getInitials(user.name),
                size: 52,
                isOnline: user.isOnline,
              ),
              title: Text(user.name),
              subtitle: Text(user.handle),
              trailing: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              onTap: () => _toggleUser(user),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _GroupInfoState(
        icon: Icons.error_outline_rounded,
        title: 'Search failed',
        subtitle: error.toString(),
      ),
    );
  }

  Widget _buildDetailsStep(BuildContext context, bool isDark) {
    final selectedUsers = _selectedUsers.values.toList();

    return ListView(
      key: const ValueKey('details-step'),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _pickGroupAvatar,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                      backgroundImage: _avatarBytes == null
                          ? null
                          : MemoryImage(_avatarBytes!),
                      child: _avatarBytes == null
                          ? const Icon(
                              CupertinoIcons.camera_fill,
                              color: AppTheme.primary,
                              size: 28,
                            )
                          : null,
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ],
              ),
              const SizedBox(width: AppTheme.spacingLg),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  enabled: !_isCreatingGroup,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Group name',
                    border: UnderlineInputBorder(),
                    enabledBorder: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _SectionHeader(title: '${selectedUsers.length} members'),
        ...selectedUsers.map(
          (user) => ListTile(
            leading: AvatarWidget(
              imageUrl: user.avatar,
              initials: _getInitials(user.name),
              size: 48,
              isOnline: user.isOnline,
            ),
            title: Text(user.name),
            subtitle: Text(user.handle),
            trailing: IconButton(
              icon: const Icon(CupertinoIcons.xmark_circle_fill),
              onPressed: _isCreatingGroup ? null : () => _toggleUser(user),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}

class _SelectedMembersStrip extends StatelessWidget {
  const _SelectedMembersStrip({
    required this.selectedUsers,
    required this.onRemove,
  });

  final List<User> selectedUsers;
  final ValueChanged<User> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLg,
          vertical: AppTheme.spacingMd,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: selectedUsers.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.spacingMd),
        itemBuilder: (context, index) {
          final user = selectedUsers[index];
          return SizedBox(
            width: 64,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AvatarWidget(
                      imageUrl: user.avatar,
                      initials: _getInitials(user.name),
                      size: 52,
                      isOnline: user.isOnline,
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () => onRemove(user),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkTertiary
                                : AppTheme.lightTertiary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  user.name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        AppTheme.spacingMd,
        AppTheme.spacingLg,
        AppTheme.spacingSm,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _GroupInfoState extends StatelessWidget {
  const _GroupInfoState({
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
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.primary),
            const SizedBox(height: AppTheme.spacingLg),
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
