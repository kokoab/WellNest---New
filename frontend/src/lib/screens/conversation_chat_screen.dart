import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/config/app_config.dart';
import 'package:my_app/models/chat_message.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/theme/app_theme.dart';

/// Single conversation: messages list + input. Subscribes to Reverb for live new messages.
class ConversationChatScreen extends StatefulWidget {
  final int conversationId;
  final String otherUserName;

  /// Resolved display URL for the other participant (optional).
  final String? otherUserProfilePhotoUrl;

  /// WellNest Assistant: suggestion chips + Ollama streaming over Reverb.
  final bool isAssistant;

  const ConversationChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserProfilePhotoUrl,
    this.isAssistant = false,
  });

  @override
  State<ConversationChatScreen> createState() => _ConversationChatScreenState();
}

class _ConversationChatScreenState extends State<ConversationChatScreen> {
  final ConversationService _service = ConversationService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _messagesPerPage = 20;
  static const double _bubbleRadius = 22;
  static const double _headerAvatarSize = 36;
  static const double _bubbleAvatarSize = 38;
  static const double _chatFontSize = 15;

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _loadingMoreMessages = false;
  bool _messagesHasMore = true;
  int _messagesPage = 1;
  String? _error;
  bool _sending = false;
  bool _uploadingAttachment = false;
  bool _pickingImage = false;
  int? _currentUserId;
  final ImagePicker _picker = ImagePicker();

  /// Non-null while the assistant is generating (shows typewriter / streaming bubble).
  String? _streamingPreview;

  static const List<String> _suggestionChips = [
    'Healthy meal ideas',
    'Quick breakfast tips',
    'Stay motivated today',
    'Light snack ideas',
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthService.instance.userId;
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _subscribeLive();
    _service.markConversationAsRead(widget.conversationId);
  }

  void _onScroll() {
    if (!_messagesHasMore || _loading || _loadingMoreMessages) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
      _messagesPage = 1;
      _messagesHasMore = true;
    });
    try {
      if (_currentUserId == null && AuthService.instance.isLoggedIn) {
        final me = await UserService.instance.fetchCurrentUser();
        if (me != null) {
          AuthService.instance.setUserId(me.id);
          _currentUserId = me.id;
        }
      }
      final data = await _service.fetchMessages(
        widget.conversationId,
        page: 1,
        perPage: _messagesPerPage,
      );
      final list = ConversationService.messagesFromResponse(data);
      final currentPage = (data['current_page'] as num?)?.toInt() ?? 1;
      final lastPage = (data['last_page'] as num?)?.toInt() ?? currentPage;
      if (mounted) {
        setState(() {
          _messages = list;
          _messagesPage = currentPage;
          _messagesHasMore = currentPage < lastPage;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
          _messagesHasMore = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingMoreMessages || !_messagesHasMore) return;
    setState(() => _loadingMoreMessages = true);
    try {
      final nextPage = _messagesPage + 1;
      final data = await _service.fetchMessages(
        widget.conversationId,
        page: nextPage,
        perPage: _messagesPerPage,
      );
      final list = ConversationService.messagesFromResponse(data);
      final currentPage = (data['current_page'] as num?)?.toInt() ?? nextPage;
      final lastPage = (data['last_page'] as num?)?.toInt() ?? currentPage;
      if (!mounted) return;
      setState(() {
        _messages.addAll(list);
        _messagesPage = currentPage;
        _messagesHasMore = currentPage < lastPage && list.isNotEmpty;
        _loadingMoreMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoreMessages = false);
    }
  }

  Future<void> _subscribeLive() async {
    try {
      await _service.subscribeToLiveMessages(
        widget.conversationId,
        (ChatMessage message) {
          if (!mounted) return;
          setState(() {
            if (widget.isAssistant &&
                _currentUserId != null &&
                message.userId != _currentUserId) {
              _streamingPreview = null;
            }
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.insert(0, message);
            }
          });
        },
        onAssistantStream: widget.isAssistant
            ? (streamId, fullText, delta, done) {
                if (!mounted) return;
                setState(() {
                  _streamingPreview = fullText;
                });
              }
            : null,
      );
    } catch (e, st) {
      assert(() {
        debugPrint('Reverb subscribe failed: $e\n$st');
        return true;
      }());
    }
  }

  @override
  void dispose() {
    _service.unsubscribeFromLiveMessages(widget.conversationId);
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      if (widget.isAssistant) {
        _streamingPreview = '';
      }
    });
    _textController.clear();
    try {
      final sent = await _service.sendMessage(widget.conversationId, text);
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == sent.id)) {
            _messages.insert(0, sent);
          }
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          if (widget.isAssistant) {
            _streamingPreview = null;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _applyChip(String prompt) {
    _textController.text = prompt;
    _send();
  }

  Widget _buildAssistantLogoAvatar(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardColor,
        border: Border.all(color: wellnestOutlineColor(context), width: 1),
      ),
      child: ClipOval(
        child: Image.asset(
          kWellnestAssistantLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => InitialsAvatar(
            name: widget.otherUserName,
            size: size,
            imageUrl: widget.otherUserProfilePhotoUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantStreamingBubble() {
    final text = _streamingPreview ?? '';
    final display = text.isEmpty ? '…' : text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          widget.isAssistant
              ? _buildAssistantLogoAvatar(context, _bubbleAvatarSize)
              : InitialsAvatar(
                  name: widget.otherUserName,
                  size: _bubbleAvatarSize,
                  imageUrl: widget.otherUserProfilePhotoUrl,
                ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(_bubbleRadius),
              ),
              child: Text(
                display,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _chatFontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const double _previewSize = 200;

  void _showAttachmentModal(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> att) {
    final path = att['file_path'] as String?;
    final name = att['file_name'] as String? ?? '';
    final type = (att['file_type'] as String? ?? '').toLowerCase();
    // Prefer path + app base URL so images load on device/emulator (server file_url may be localhost).
    final fullUrl = path != null && path.isNotEmpty
        ? '${AppConfig.baseUrl}/storage/$path'
        : null;
    if (fullUrl != null && (type.contains('image') || type.isEmpty)) {
      return GestureDetector(
        onTap: () => _showAttachmentModal(fullUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            fullUrl,
            width: _previewSize,
            height: _previewSize,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: _previewSize,
                height: _previewSize,
                color: Colors.black12,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes!).toDouble()
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              width: _previewSize,
              height: _previewSize,
              color: Colors.black12,
              child: const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.white70, size: 20),
          const SizedBox(width: 6),
          Text(
            name.isNotEmpty ? name : 'Attachment',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSendAttachment() async {
    if (_sending || _uploadingAttachment || _pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      setState(() => _pickingImage = false);
      if (picked == null) return;
      setState(() => _uploadingAttachment = true);
      try {
        final bytes = await picked.readAsBytes();
        final text = _textController.text.trim();
        if (text.isNotEmpty) _textController.clear();
        final content = text;
        final sent = await _service.sendMessage(widget.conversationId, content);
        final attachmentData = await _service.uploadMessageAttachment(
          sent.id,
          bytes,
          picked.name,
        );
        if (!mounted) return;
        final updatedAttachments = [...sent.attachments, attachmentData];
        final updatedMessage = ChatMessage.fromJson({
          'id': sent.id,
          'conversation_id': sent.conversationId,
          'user_id': sent.userId,
          'content': sent.content,
          'read_at': sent.readAt,
          'created_at': sent.createdAt,
          'user': sent.user != null
              ? {'id': sent.user!.id, 'name': sent.user!.name}
              : null,
          'attachments': updatedAttachments,
        });
        setState(() {
          _messages.removeWhere((m) => m.id == sent.id);
          _messages.insert(0, updatedMessage);
          _uploadingAttachment = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() => _uploadingAttachment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pickingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = wellnestOutlineColor(context);
    final dividerColor = outline.withValues(alpha: 0.55);
    final screenW = MediaQuery.sizeOf(context).width;

    final statusTop = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.discoverHeroFadeTo(Theme.of(context).scaffoldBackgroundColor),
          ),
          child: Column(
            children: [
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: statusTop),
                    SizedBox(
                      height: kToolbarHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: screenW - 112,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    widget.isAssistant
                                        ? _buildAssistantLogoAvatar(
                                            context,
                                            _headerAvatarSize,
                                          )
                                        : InitialsAvatar(
                                            name: widget.otherUserName,
                                            size: _headerAvatarSize,
                                            imageUrl:
                                                widget.otherUserProfilePhotoUrl,
                                          ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        widget.otherUserName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 0,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 26,
                              ),
                              color: AppColors.primaryGreen,
                              onPressed: () => Navigator.of(context).maybePop(),
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: dividerColor),
                  ],
                ),
              ),
              Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadMessages,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _messages.isEmpty &&
                        !(widget.isAssistant && _streamingPreview != null)
                  ? const Center(child: Text('No messages yet. Say hello!'))
                  : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount:
                        _messages.length +
                        (widget.isAssistant && _streamingPreview != null
                            ? 1
                            : 0) +
                        (_loadingMoreMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loadingMoreMessages &&
                          index ==
                              _messages.length +
                                  (widget.isAssistant &&
                                          _streamingPreview != null
                                      ? 1
                                      : 0)) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final streamExtra =
                          widget.isAssistant && _streamingPreview != null
                          ? 1
                          : 0;
                      if (streamExtra == 1 && index == 0) {
                        return _buildAssistantStreamingBubble();
                      }
                      final mi = index - streamExtra;
                      final m = _messages[mi];
                      final isMe =
                          _currentUserId != null && m.userId == _currentUserId;
                      final attachmentOnly =
                          m.attachments.isNotEmpty && m.content.trim().isEmpty;
                      final otherPhoto =
                          m.user?.displayProfilePhotoUrl ??
                          widget.otherUserProfilePhotoUrl;
                      final Color bubbleBg;
                      final Color bubbleFg;
                      if (widget.isAssistant) {
                        bubbleBg = isMe
                            ? Colors.grey.shade700
                            : AppColors.primaryGreen.withValues(alpha: 0.9);
                        bubbleFg = Colors.white;
                      } else {
                        bubbleBg = isMe
                            ? AppColors.primaryGreen.withValues(alpha: 0.9)
                            : Colors.grey.shade700;
                        bubbleFg = Colors.white;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              widget.isAssistant
                                  ? _buildAssistantLogoAvatar(
                                      context,
                                      _bubbleAvatarSize,
                                    )
                                  : InitialsAvatar(
                                      name: m.user?.name ?? widget.otherUserName,
                                      size: _bubbleAvatarSize,
                                      imageUrl: otherPhoto,
                                    ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: attachmentOnly ? 0 : 14,
                                  vertical: attachmentOnly ? 0 : 10,
                                ),
                                decoration: attachmentOnly
                                    ? null
                                    : BoxDecoration(
                                        color: bubbleBg,
                                        borderRadius:
                                            BorderRadius.circular(_bubbleRadius),
                                      ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (m.attachments.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: attachmentOnly ? 0 : 6,
                                        ),
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            for (final att in m.attachments)
                                              _buildAttachmentPreview(att),
                                          ],
                                        ),
                                      ),
                                    if (m.content.trim().isNotEmpty)
                                      Text(
                                        m.content,
                                        style: TextStyle(
                                          color: bubbleFg,
                                          fontSize: _chatFontSize,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ),
          if (widget.isAssistant) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: outline.withValues(alpha: 0.55),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chip in _suggestionChips)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(chip),
                            onPressed: _sending ? null : () => _applyChip(chip),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            backgroundColor: AppColors.primaryGreen.withValues(
                              alpha: 0.12,
                            ),
                            labelStyle: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Container(
            height: 1,
            width: double.infinity,
            color: dividerColor,
          ),
          SafeArea(
            top: false,
            left: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed:
                        (_sending ||
                            _uploadingAttachment ||
                            _pickingImage ||
                            widget.isAssistant)
                        ? null
                        : _pickAndSendAttachment,
                    icon: _uploadingAttachment
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.75),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide(color: outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide(color: outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: const BorderSide(
                            color: AppColors.primaryGreen,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        (_sending || _uploadingAttachment || _pickingImage)
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }
}
