import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/config/app_config.dart';
import 'package:my_app/models/chat_message.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/conversation_service.dart';
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
          if (_currentUserId == null && list.isNotEmpty) {
            _currentUserId = list.first.userId;
          }
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
    } catch (_) {
      // Reverb optional; app still works without it
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

  Widget _buildAssistantStreamingBubble(bool isDark) {
    final text = _streamingPreview ?? '';
    final display = text.isEmpty ? '…' : text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InitialsAvatar(
            name: widget.otherUserName,
            size: 28,
            imageUrl: widget.otherUserProfilePhotoUrl,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                display,
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InitialsAvatar(
              name: widget.otherUserName,
              size: 32,
              imageUrl: widget.otherUserProfilePhotoUrl,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
      ),
      body: Column(
        children: [
          Expanded(
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
                        return _buildAssistantStreamingBubble(isDark);
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              InitialsAvatar(
                                name: m.user?.name ?? widget.otherUserName,
                                size: 28,
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
                                        color: isMe
                                            ? AppColors.primaryGreen.withValues(
                                                alpha: 0.9,
                                              )
                                            : (isDark
                                                  ? Colors.grey.shade700
                                                  : Colors.grey.shade700),
                                        borderRadius: BorderRadius.circular(16),
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              InitialsAvatar(
                                name: 'Me',
                                size: 28,
                                imageUrl: null,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (widget.isAssistant)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
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
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 17),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
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
    );
  }
}
