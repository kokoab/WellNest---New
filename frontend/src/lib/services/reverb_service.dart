import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

/// Connects to Laravel Reverb (WebSocket) for real-time events.
/// Use [subscribeToConversation] when opening a chat; [unsubscribeFromConversation] when leaving.
class ReverbService {
  ReverbService._();

  static final ReverbService _instance = ReverbService._();
  static ReverbService get instance => _instance;

  final Map<int, Channel> _channels = {};
  final Map<int, Channel> _notificationChannels = {};
  final Map<int, List<VoidCallback>> _notificationListeners = {};
  bool _initialized = false;

  ReverbClient get _client {
    return ReverbClient.instance(
      host: AppConfig.reverbHost,
      port: AppConfig.reverbPort,
      appKey: AppConfig.reverbAppKey,
      authorizer: _authorizer,
      authEndpoint: AppConfig.broadcastingAuthUrl,
    );
  }

  Future<Map<String, String>> _authorizer(
    String channelName,
    String socketId,
  ) async {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  /// Connect to Reverb (call once when user is logged in and you need live updates).
  Future<void> connect() async {
    if (_initialized) return;
    if (!AuthService.instance.isLoggedIn) return;
    await _client.connect();
    _initialized = true;
  }

  /// Disconnect (e.g. on logout).
  void disconnect() {
    for (final c in _channels.values) {
      c.unsubscribe();
    }
    for (final c in _notificationChannels.values) {
      c.unsubscribe();
    }
    _channels.clear();
    _notificationChannels.clear();
    _notificationListeners.clear();
    _client.disconnect();
    _initialized = false;
  }

  Future<void> subscribeToNotificationUpdates(
    int userId,
    VoidCallback onUpdate,
  ) async {
    if (!_initialized) await connect();

    final listeners = _notificationListeners.putIfAbsent(userId, () => []);
    if (!listeners.contains(onUpdate)) {
      listeners.add(onUpdate);
    }

    if (_notificationChannels.containsKey(userId)) return;

    final channelName = 'notifications.$userId';
    final channel = _client.subscribeToPrivateChannel(channelName);

    void handleUpdate(String eventName, dynamic data) {
      for (final listener in List<VoidCallback>.from(
        _notificationListeners[userId] ?? const [],
      )) {
        listener();
      }
    }

    channel.bind('notification.badge.updated', handleUpdate);
    channel.bind('.notification.badge.updated', handleUpdate);
    _notificationChannels[userId] = channel;
  }

  Future<void> unsubscribeFromNotificationUpdates(
    int userId,
    VoidCallback onUpdate,
  ) async {
    final listeners = _notificationListeners[userId];
    if (listeners == null) return;
    listeners.remove(onUpdate);
    if (listeners.isNotEmpty) return;

    _notificationListeners.remove(userId);
    final channel = _notificationChannels.remove(userId);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Subscribe to new messages in a conversation. [onMessage] receives the payload from the backend (map with 'message' key).
  /// [onAssistantStream] receives Ollama streaming chunks (`assistant.stream`).
  /// Call [unsubscribeFromConversation] when leaving the conversation screen.
  Future<void> subscribeToConversation(
    int conversationId,
    void Function(Map<String, dynamic> payload) onMessage, {
    void Function(Map<String, dynamic> payload)? onAssistantStream,
  }) async {
    if (_channels.containsKey(conversationId)) return;
    if (!_initialized) await connect();

    final channelName = 'private-conversation.$conversationId';
    final channel = _client.subscribeToPrivateChannel(channelName);
    void handleEvent(String eventName, dynamic data) {
      final payload = _coercePayload(data);
      if (payload != null) {
        onMessage(payload);
      }
    }

    void handleAssistantStream(String eventName, dynamic data) {
      if (onAssistantStream == null) return;
      final payload = _coercePayload(data);
      if (payload != null) {
        onAssistantStream(payload);
      }
    }

    // Some clients prepend a dot for custom events. Bind both.
    channel.bind('message.new', handleEvent);
    channel.bind('.message.new', handleEvent);
    if (onAssistantStream != null) {
      channel.bind('assistant.stream', handleAssistantStream);
      channel.bind('.assistant.stream', handleAssistantStream);
    }
    _channels[conversationId] = channel;
  }

  Map<String, dynamic>? _coercePayload(dynamic data) {
    dynamic value = data;

    // Plugin can pass payload as raw JSON string.
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      try {
        value = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }

    if (value is! Map) return null;
    var map = Map<String, dynamic>.from(value);

    // Some transport layers wrap payload in "data".
    final wrapped = map['data'];
    if (wrapped is String) {
      final trimmed = wrapped.trim();
      if (trimmed.isNotEmpty) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            map = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          // Keep original map if wrapped data is not JSON.
        }
      }
    } else if (wrapped is Map) {
      map = Map<String, dynamic>.from(wrapped);
    }

    return map;
  }

  /// Unsubscribe from a conversation channel (call when leaving the chat screen).
  Future<void> unsubscribeFromConversation(int conversationId) async {
    final channel = _channels.remove(conversationId);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Optional: expose connection state for UI (e.g. "Live" / "Reconnecting").
  Stream<ConnectionState> get connectionState =>
      _client.onConnectionStateChange;
}
