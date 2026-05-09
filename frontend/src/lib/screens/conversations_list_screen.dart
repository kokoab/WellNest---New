import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_app/models/conversation_list_item.dart';
import 'package:my_app/models/user_search_result.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/screens/conversation_chat_screen.dart';

/// Lists the user's conversations. Search bar to find users and start a new chat.
class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final ConversationService _service = ConversationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _conversationsScrollController = ScrollController();
  static const int _conversationsPerPage = 20;

  List<ConversationListItem> _conversations = [];
  List<UserSearchResult> _searchResults = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  bool _searching = false;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _conversationsScrollController.addListener(_onConversationsScroll);
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  void _onConversationsScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (_searchController.text.trim().isNotEmpty) return;
    final pos = _conversationsScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _conversationsScrollController.removeListener(_onConversationsScroll);
    _conversationsScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {}); // show clear button and search UI
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
      }
      return;
    }
    setState(() => _searching = true);
    try {
      final list = await _service.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = list;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _load() async {
    if (!AuthService.instance.isLoggedIn) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please log in.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      await _service.ensureAssistantConversation();
      final response = await _service.fetchConversationsPaginated(
        page: 1,
        perPage: _conversationsPerPage,
      );
      if (mounted) {
        setState(() {
          _conversations = response.conversations;
          _page = response.currentPage;
          _hasMore = response.currentPage < response.lastPage;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final response = await _service.fetchConversationsPaginated(
        page: nextPage,
        perPage: _conversationsPerPage,
      );
      if (!mounted) return;
      final existingIds = _conversations.map((c) => c.id).toSet();
      final incoming = response.conversations
          .where((c) => !existingIds.contains(c.id))
          .toList();
      setState(() {
        _conversations.addAll(incoming);
        _page = response.currentPage;
        _hasMore = response.currentPage < response.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _startChatWith(UserSearchResult user) async {
    _searchController.clear();
    setState(() => _searchResults = []);
    try {
      final conversation = await _service.createConversation(
        user.id,
        user.name,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ConversationChatScreen(
            conversationId: conversation.id,
            otherUserName: user.name,
            otherUserProfilePhotoUrl: user.displayProfilePhotoUrl,
            isAssistant: false,
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSearchResults = _searchController.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Messages',
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 26),
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search users to message...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading && !showSearchResults
                ? const Center(child: CircularProgressIndicator())
                : _error != null && !showSearchResults
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : showSearchResults
                ? _buildSearchResults()
                : _conversations.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No conversations yet. Search for a user above to start a chat.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _conversationsScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversations.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == _conversations.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final c = _conversations[index];
                        final timeStr = c.lastMessage?.createdAt != null
                            ? formatPostTime(c.lastMessage!.createdAt)
                            : (c.lastMessageAt != null
                                  ? formatPostTime(c.lastMessageAt)
                                  : null);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => ConversationChatScreen(
                                    conversationId: c.id,
                                    otherUserName: c.otherUser.name,
                                    otherUserProfilePhotoUrl:
                                        c.otherUser.displayProfilePhotoUrl,
                                    isAssistant: c.isAssistant,
                                  ),
                                ),
                              );
                              _load();
                            },
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InitialsAvatar(
                                    name: c.otherUser.name,
                                    size: 52,
                                    imageUrl:
                                        c.otherUser.displayProfilePhotoUrl,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (c.isAssistant) ...[
                                              Icon(
                                                Icons.auto_awesome,
                                                size: 18,
                                                color: AppColors.accentOrange,
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                c.otherUser.name,
                                                style: textTheme.titleSmall
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c.lastMessage != null
                                              ? c.lastMessage!.content
                                              : (c.isAssistant
                                                    ? 'Ask for wellness tips, meals, or motivation'
                                                    : 'No messages yet'),
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (timeStr != null && timeStr.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        timeStr,
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  if (c.unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentOrange,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                      ),
                                      child: Text(
                                        '${c.unreadCount > 99 ? 99 : c.unreadCount}',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No users found. Try a different name.'),
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: InitialsAvatar(
            name: user.name,
            size: 44,
            imageUrl: user.displayProfilePhotoUrl,
          ),
          title: Text(user.name),
          subtitle: const Text('Tap to start conversation'),
          onTap: () => _startChatWith(user),
        );
      },
    );
  }
}
