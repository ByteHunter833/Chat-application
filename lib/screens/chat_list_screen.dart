import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../repositories/chat_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_tile.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/start_chat_sheet.dart';
import '../widgets/state_widgets.dart';
import 'chat_detail_screen.dart';
import 'create_group_process_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  static const double _splitLayoutBreakpoint = 900;

  final TextEditingController _searchController = TextEditingController();
  Chat? _selectedChat;
  bool _selectedChatIsDraft = false;

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

  Future<void> _showStartChatSheet() async {
    final targetUser = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const StartChatSheet(),
    );

    if (!mounted || targetUser == null) {
      return;
    }

    final currentUser = ref.read(currentAppUserProvider).value;
    if (currentUser == null) {
      return;
    }

    try {
      final existingChat = await ref
          .read(chatRepositoryProvider)
          .getDirectChatIfExists(
            currentUser: currentUser,
            otherUser: targetUser,
          );
      if (!mounted) {
        return;
      }

      final isDraft = existingChat?.lastMessage == null;
      final chat = existingChat ?? _buildDraftChat(currentUser, targetUser);
      _openChat(chat, isDraft: isDraft);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to open chat: $error')));
    }
  }

  Chat _buildDraftChat(User currentUser, User targetUser) {
    final members = <String>[currentUser.id, targetUser.id]..sort();
    final now = DateTime.now();
    return Chat(
      id: directChatIdFor(currentUser.id, targetUser.id),
      otherUser: targetUser,
      createdAt: now,
      updatedAt: now,
      members: members,
    );
  }

  void _openChat(Chat chat, {bool isDraft = false}) {
    if (_usesSplitLayout(context)) {
      setState(() {
        _selectedChat = chat;
        _selectedChatIsDraft = isDraft;
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(chat: chat, isDraft: isDraft),
      ),
    );
  }

  void _clearSelectedChat() {
    setState(() {
      _selectedChat = null;
      _selectedChatIsDraft = false;
    });
  }

  bool _usesSplitLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= _splitLayoutBreakpoint;
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  void _openCreateGroupProcess() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupProcessScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentAppUserProvider).value;
    final chatsAsync = ref.watch(chatsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesSplitLayout = constraints.maxWidth >= _splitLayoutBreakpoint;
        final listBody = _buildChatListBody(
          context,
          chatsAsync: chatsAsync,
          isDark: isDark,
        );

        if (!usesSplitLayout) {
          return Scaffold(
            backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
            appBar: _buildAppBar(context, currentUser, themeMode),
            body: listBody,
            floatingActionButton: _buildFloatingActions(),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
          body: Row(
            children: [
              Expanded(
                child: Scaffold(
                  backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
                  appBar: _buildAppBar(context, currentUser, themeMode),
                  body: listBody,
                  floatingActionButton: _buildFloatingActions(),
                ),
              ),
              Container(
                width: 1,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              Expanded(child: _buildConversationPane(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatListBody(
    BuildContext context, {
    required AsyncValue<List<Chat>> chatsAsync,
    required bool isDark,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or message...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingMd,
                ),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _searchController.clear,
                      )
                    : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: chatsAsync.when(
            data: (chats) => _buildChatsList(
              context,
              chats: _filterChats(chats),
              isDark: isDark,
            ),
            loading: () => ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) => const ChatTileSkeleton(),
            ),
            error: (error, stackTrace) => ErrorStateWidget(
              title: 'Unable to load chats',
              subtitle: error.toString(),
              onRetry: () => ref.invalidate(chatsProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'create_group',
          tooltip: 'New group',
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          onPressed: _openCreateGroupProcess,
          child: const Icon(CupertinoIcons.person_2_fill),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        FloatingActionButton.extended(
          heroTag: 'new_chat',
          backgroundColor: AppTheme.primary,
          onPressed: _showStartChatSheet,
          icon: const Icon(Icons.alternate_email_rounded, color: Colors.white),
          label: const Text(
            'New chat',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationPane(BuildContext context) {
    final selectedChat = _selectedChat;
    if (selectedChat == null) {
      return _ConversationPlaceholder(onStartChat: _showStartChatSheet);
    }

    return ChatDetailScreen(
      key: ValueKey(
        '${selectedChat.id}-${_selectedChatIsDraft ? 'draft' : 'active'}',
      ),
      chat: selectedChat,
      isDraft: _selectedChatIsDraft,
      showBackButton: false,
      onClose: _clearSelectedChat,
    );
  }

  List<Chat> _filterChats(List<Chat> chats) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return chats;
    }

    return chats.where((chat) {
      return chat.displayName.toLowerCase().contains(query) ||
          chat.otherUser.username.toLowerCase().contains(query) ||
          (chat.lastMessage?.content.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    dynamic currentUser,
    dynamic themeMode,
  ) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Messages'),
          if (currentUser != null)
            Text(
              currentUser.handle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
          ),
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'sign_out') {
              _signOut();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(value: 'sign_out', child: Text('Sign out')),
          ],
        ),
      ],
    );
  }

  Widget _buildChatsList(
    BuildContext context, {
    required List<Chat> chats,
    required bool isDark,
  }) {
    if (chats.isEmpty) {
      return EmptyStateWidget(
        title: 'No conversations yet',
        subtitle:
            'Find people by their @username and start a direct message thread.',
        icon: Icons.alternate_email_rounded,
        onAction: _showStartChatSheet,
        actionLabel: 'Start chat',
      );
    }

    final directChats = chats.where((chat) => !chat.isGroup).toList();
    final groupChats = chats.where((chat) => chat.isGroup).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppTheme.spacingLg,
              0,
              AppTheme.spacingLg,
              AppTheme.spacingSm,
            ),

            child: TabBar(
              dividerColor: Colors.transparent,

              labelColor: isDark
                  ? AppTheme.lightTextSecondary
                  : AppTheme.lightTextPrimary,
              unselectedLabelColor: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              tabs: const [
                Tab(text: 'Personal Chats'),
                Tab(text: 'Groups'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildChatTab(
                  context,
                  chats: directChats,
                  emptyTitle: 'No direct chats yet',
                  emptySubtitle:
                      'Find people by their @username and start a direct message thread.',
                  emptyIcon: Icons.alternate_email_rounded,
                  onEmptyAction: _showStartChatSheet,
                  emptyActionLabel: 'Start chat',
                ),
                _buildChatTab(
                  context,
                  chats: groupChats,
                  emptyTitle: 'No groups yet',
                  emptySubtitle:
                      'Create a group chat to keep a shared conversation in one place.',
                  emptyIcon: CupertinoIcons.person_2_fill,
                  onEmptyAction: _openCreateGroupProcess,
                  emptyActionLabel: 'New group',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab(
    BuildContext context, {
    required List<Chat> chats,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required VoidCallback onEmptyAction,
    required String emptyActionLabel,
  }) {
    if (chats.isEmpty) {
      return EmptyStateWidget(
        title: emptyTitle,
        subtitle: emptySubtitle,
        icon: emptyIcon,
        onAction: onEmptyAction,
        actionLabel: emptyActionLabel,
      );
    }

    final pinnedChats = chats.where((chat) => chat.isPinned).toList();
    final regularChats = chats.where((chat) => !chat.isPinned).toList();

    return CustomScrollView(
      slivers: [
        if (pinnedChats.isNotEmpty) _buildSectionHeader(context, 'Pinned'),
        _buildChatSliverList(pinnedChats),
        if (regularChats.isNotEmpty && pinnedChats.isNotEmpty)
          _buildSectionHeader(context, 'Recent'),
        _buildChatSliverList(regularChats),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          top: AppTheme.spacingMd,
          bottom: AppTheme.spacingSm,
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }

  Widget _buildChatSliverList(List<Chat> chats) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final chat = chats[index];
        return ChatTile(
          chat: chat,
          isSelected: _selectedChat?.id == chat.id,
          onTap: () => _openChat(chat),
        );
      }, childCount: chats.length),
    );
  }
}

class _ConversationPlaceholder extends StatelessWidget {
  const _ConversationPlaceholder({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.forum_outlined,
                      color: AppTheme.primary,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  Text(
                    "Choose who you'd like to message",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'Select a conversation from the list or start a new chat.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: secondaryColor),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),
                  ElevatedButton.icon(
                    onPressed: onStartChat,
                    icon: const Icon(Icons.alternate_email_rounded),
                    label: const Text('Start chat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
