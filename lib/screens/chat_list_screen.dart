import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_tile.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/start_chat_sheet.dart';
import '../widgets/state_widgets.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

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
    final chat = await showModalBottomSheet<Chat>(
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

    if (!mounted || chat == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
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
      ),
      body: Column(
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _showStartChatSheet,
        icon: const Icon(Icons.alternate_email_rounded, color: Colors.white),
        label: const Text(
          'New chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  List<Chat> _filterChats(List<Chat> chats) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return chats;
    }

    return chats.where((chat) {
      return chat.otherUser.name.toLowerCase().contains(query) ||
          chat.otherUser.username.toLowerCase().contains(query) ||
          (chat.lastMessage?.content.toLowerCase().contains(query) ?? false);
    }).toList();
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

    final pinnedChats = chats.where((chat) => chat.isPinned).toList();
    final regularChats = chats.where((chat) => !chat.isPinned).toList();

    return CustomScrollView(
      slivers: [
        if (pinnedChats.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacingLg,
                right: AppTheme.spacingLg,
                top: AppTheme.spacingMd,
                bottom: AppTheme.spacingSm,
              ),
              child: Text(
                'Pinned',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final chat = pinnedChats[index];
            return ChatTile(
              chat: chat,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
              ),
            );
          }, childCount: pinnedChats.length),
        ),
        if (regularChats.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacingLg,
                right: AppTheme.spacingLg,
                top: AppTheme.spacingMd,
                bottom: AppTheme.spacingSm,
              ),
              child: Text(
                'All messages',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final chat = regularChats[index];
            return ChatTile(
              chat: chat,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
              ),
            );
          }, childCount: regularChats.length),
        ),
      ],
    );
  }
}
