import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/config/app_config.dart';
import 'package:my_app/models/chat_message.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/quota_exceeded_dialog.dart';
import 'package:my_app/widgets/system_refusal_bubble.dart';

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

  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _uploadingAttachment = false;
  bool _pickingImage = false;
  int? _currentUserId;
  CurrentUser? _currentUser;
  final ImagePicker _picker = ImagePicker();
  Timer? _syncTimer;

  /// Non-null while the assistant is generating (shows typewriter / streaming bubble).
  String? _streamingPreview;

  /// True once the backend returns 429 — disables the composer until the screen is re-opened.
  bool _quotaBlocked = false;

  static const List<String> _suggestionChips = [
    'Healthy meal ideas',
    'Quick breakfast tips',
    'Stay motivated today',
    'Light snack ideas',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();
    _subscribeLive();
    _startBackgroundSync();
    _service.markConversationAsRead(widget.conversationId);
  }

  Future<void> _loadCurrentUser() async {
    if (!AuthService.instance.isLoggedIn) return;
    final user = await UserService.instance.fetchCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _currentUser = user;
        _currentUserId = user.id;
      });
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchMessages(widget.conversationId);
      final list = ConversationService.messagesFromResponse(data);
      if (mounted)
        setState(() {
          _messages = list;
          _loading = false;
          if (_currentUserId == null && list.isNotEmpty)
            _currentUserId = list.first.userId;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
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
    _syncTimer?.cancel();
    _service.unsubscribeFromLiveMessages(widget.conversationId);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncMessagesSilently();
    });
  }

  Future<void> _syncMessagesSilently() async {
    if (!mounted || _loading || _sending || _uploadingAttachment) return;
    try {
      final data = await _service.fetchMessages(widget.conversationId);
      final latest = ConversationService.messagesFromResponse(data);
      if (!mounted || latest.isEmpty) return;

      final existingIds = _messages.map((m) => m.id).toSet();
      final unseen = latest.where((m) => !existingIds.contains(m.id)).toList();
      if (unseen.isEmpty) return;

      setState(() {
        _messages = [...unseen, ..._messages];
      });
    } catch (_) {
      // Keep UI stable if polling fails; realtime push may still arrive.
    }
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
    } on QuotaExceededException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _quotaBlocked = true;
          if (widget.isAssistant) _streamingPreview = null;
        });
        QuotaExceededDialog.show(context, retryAfter: e.retryAfter);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final text = _streamingPreview ?? '';
    final display = text.isEmpty ? '…' : text;
    final refusal = text.isNotEmpty && isAssistantRefusal(text);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
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
            child: refusal
                ? SystemRefusalBubble(text: display)
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Text(
                      display,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 17,
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
    final colorScheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.88),
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
                      child: CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: colorScheme.onSurfaceVariant,
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
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> att) {
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.surfaceContainerHighest,
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
            errorBuilder: (_, __, ___) => Container(
              width: _previewSize,
              height: _previewSize,
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 6),
          Text(
            name.isNotEmpty ? name : 'Attachment',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

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
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 26),
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
                : _messages.isEmpty && !(widget.isAssistant && _streamingPreview != null)
                ? const Center(child: Text('No messages yet. Say hello!'))
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount:
                        _messages.length +
                        (widget.isAssistant && _streamingPreview != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      final streamExtra =
                          widget.isAssistant && _streamingPreview != null ? 1 : 0;
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
                          m.user?.displayProfilePhotoUrl ?? widget.otherUserProfilePhotoUrl;
                      final isRefusal = !isMe &&
                          widget.isAssistant &&
                          m.content.trim().isNotEmpty &&
                          isAssistantRefusal(m.content);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                              child: isRefusal
                                  ? SystemRefusalBubble(text: m.content)
                                  : Container(
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
                                                  ? colorScheme.primary
                                                  : (isDark
                                                      ? colorScheme.surfaceContainerHighest
                                                      : colorScheme.surfaceContainerLow),
                                              borderRadius: BorderRadius.circular(
                                                AppRadii.md,
                                              ),
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
                                              style: textTheme.bodyLarge?.copyWith(
                                                color: isMe
                                                    ? colorScheme.onPrimary
                                                    : colorScheme.onSurface,
                                                fontSize: 17,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              InitialsAvatar(
                                name: _currentUser?.displayName ?? 'Me',
                                size: 28,
                                imageUrl: _currentUser?.displayProfilePhotoUrl,
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
                            onPressed: (_sending || _quotaBlocked) ? null : () => _applyChip(chip),
                            backgroundColor: colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            labelStyle: textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
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
                    tooltip: 'Attach image',
                    onPressed:
                        (_sending || _uploadingAttachment || _pickingImage || widget.isAssistant || _quotaBlocked)
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
                      foregroundColor: colorScheme.primary,
                      minimumSize: const Size.square(kMinTapTargetSize),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_quotaBlocked,
                      style: textTheme.bodyLarge?.copyWith(fontSize: 17),
                      decoration: InputDecoration(
                        hintText: _quotaBlocked
                            ? 'Daily limit reached'
                            : 'Type a message...',
                        hintStyle: textTheme.bodyMedium?.copyWith(fontSize: 17),
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
                    tooltip: 'Send message',
                    onPressed:
                        (_sending || _uploadingAttachment || _pickingImage || _quotaBlocked)
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size.square(kMinTapTargetSize),
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
