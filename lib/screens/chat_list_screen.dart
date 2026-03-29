import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/mock_data.dart';
import '../widgets/chat_tile.dart';
import '../widgets/loading_skeleton.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const ChatListScreen({super.key, required this.onThemeToggle});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _chats = MockData.mockChats;
      _filteredChats = _chats;
      _isLoading = false;
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats
            .where(
              (chat) =>
                  chat.otherUser.name.toLowerCase().contains(query) ||
                  (chat.lastMessage?.content.toLowerCase().contains(query) ??
                      false),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinnedChats = _filteredChats.where((c) => c.isPinned).toList();
    final regularChats = _filteredChats.where((c) => !c.isPinned).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkTertiary : AppTheme.lightTertiary,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: AppTheme.spacingMd,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          // Chat List
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _buildListContent(pinnedChats, regularChats, isDark),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Start new chat feature'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const ChatTileSkeleton(),
    );
  }

  Widget _buildListContent(
    List<Chat> pinnedChats,
    List<Chat> regularChats,
    bool isDark,
  ) {
    if (_filteredChats.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return CustomScrollView(
      slivers: [
        // Pinned Chats Section
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(chat: chat),
                  ),
                );
              },
              onDelete: () {
                _deletChat(chat);
              },
              onMute: () {
                _muteChat(chat);
              },
              onPin: () {
                _togglePin(chat);
              },
            );
          }, childCount: pinnedChats.length),
        ),
        // Regular Chats Section
        if (regularChats.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppTheme.spacingLg,
                right: AppTheme.spacingLg,
                top: regularChats.isEmpty ? 0 : AppTheme.spacingMd,
                bottom: AppTheme.spacingSm,
              ),
              child: Text(
                'All Messages',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final chat = regularChats[index];
            return ChatTile(
              chat: chat,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(chat: chat),
                  ),
                );
              },
              onDelete: () {
                _deletChat(chat);
              },
              onMute: () {
                _muteChat(chat);
              },
              onPin: () {
                _togglePin(chat);
              },
            );
          }, childCount: regularChats.length),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Start a new chat to begin messaging',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppTheme.spacingXl),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New chat feature'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _deletChat(Chat chat) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _chats.removeWhere((c) => c.id == chat.id);
          _filteredChats.removeWhere((c) => c.id == chat.id);
        });
      }
    });
  }

  void _muteChat(Chat chat) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          final index = _chats.indexWhere((c) => c.id == chat.id);
          if (index != -1) {
            _chats[index] = Chat(
              id: chat.id,
              otherUser: chat.otherUser,
              lastMessage: chat.lastMessage,
              unreadCount: chat.unreadCount,
              isPinned: chat.isPinned,
              isMuted: !chat.isMuted,
              createdAt: chat.createdAt,
            );
            _filterChats();
          }
        });
      }
    });
  }

  void _togglePin(Chat chat) {
    setState(() {
      final index = _chats.indexWhere((c) => c.id == chat.id);
      if (index != -1) {
        _chats[index] = Chat(
          id: chat.id,
          otherUser: chat.otherUser,
          lastMessage: chat.lastMessage,
          unreadCount: chat.unreadCount,
          isPinned: !chat.isPinned,
          isMuted: chat.isMuted,
          createdAt: chat.createdAt,
        );
        _filterChats();
      }
    });
  }
}
