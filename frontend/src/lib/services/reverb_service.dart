import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pusher_reverb_flutter/pusher_reverb_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import 'admin_auth_service.dart';
import 'auth_service.dart';

typedef _MessageHandler = void Function(Map<String, dynamic> payload);
typedef _AssistantStreamHandler = void Function(Map<String, dynamic> payload);

class _ConversationHandlers {
  _ConversationHandlers({
    required this.onMessage,
    this.onAssistantStream,
  });

  _MessageHandler onMessage;
  _AssistantStreamHandler? onAssistantStream;
}

/// Connects to Laravel Reverb (WebSocket) for real-time events.
/// Use [subscribeToConversation] when opening a chat; [unsubscribeFromConversation] when leaving.
class ReverbService {
  ReverbService._();

  static final ReverbService _instance = ReverbService._();
  static ReverbService get instance => _instance;

  final Map<int, Channel> _channels = {};
  final Map<int, _ConversationHandlers> _conversationHandlers = {};
  final Map<int, Channel> _notificationChannels = {};
  final Map<int, List<VoidCallback>> _notificationListeners = {};
  bool _initialized = false;
  bool _reconnectScheduled = false;
  StreamSubscription<ConnectionState>? _connectionSubscription;

  /// In-flight connect so parallel subscribers share one handshake.
  Future<void>? _connectFuture;

  int _reconnectBackoffSeconds = 2;
  static const int _maxReconnectBackoffSeconds = 60;

  ReverbClient get _client {
    // Web: default IOWebSocketChannel uses dart:io → Unsupported operation: Platform._version.
    // Use cross-platform WebSocketChannel.connect via [channelFactory] on first init only.
    return ReverbClient.instance(
      host: AppConfig.reverbHost,
      port: AppConfig.reverbPort,
      appKey: AppConfig.reverbAppKey,
      authorizer: _authorizer,
      authEndpoint: AppConfig.broadcastingAuthUrl,
      channelFactory: kIsWeb ? WebSocketChannel.connect : null,
    );
  }

  String? get _authToken {
    final userToken = AuthService.instance.token;
    if (userToken != null && userToken.isNotEmpty) {
      return userToken;
    }
    final adminToken = AdminAuthService.instance.token;
    if (adminToken != null && adminToken.isNotEmpty) {
      return adminToken;
    }
    return null;
  }

  bool get _canConnect =>
      AuthService.instance.isLoggedIn || AdminAuthService.instance.isLoggedIn;

  Future<Map<String, String>> _authorizer(
    String channelName,
    String socketId,
  ) async {
    final token = _authToken;
    if (token == null || token.isEmpty) return {};
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  /// Connect to Reverb (call once when user is logged in and you need live updates).
  Future<void> connect() async {
    if (!_canConnect) return;
    final client = _client;
    if (_initialized && client.socketId != null) return;

    _connectFuture ??= _connectUntilSocketReady();
    try {
      await _connectFuture;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _connectUntilSocketReady() async {
    final client = _client;
    if (_initialized && client.socketId != null) return;

    _ensureConnectionListener();

    final connected = client.onConnectionStateChange
        .where(
          (s) => s == ConnectionState.connected && client.socketId != null,
        )
        .first;

    await client.connect();

    if (client.socketId != null) {
      _initialized = true;
      return;
    }

    await connected.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Reverb: timed out waiting for socket id (check REVERB_PORT / server)',
      ),
    );
    _initialized = true;
  }

  void _ensureConnectionListener() {
    _connectionSubscription ??=
        _client.onConnectionStateChange.listen(_onConnectionStateChange);
  }

  void _onConnectionStateChange(ConnectionState state) {
    if (state == ConnectionState.connected) {
      _reconnectScheduled = false;
      _reconnectBackoffSeconds = 2;
      return;
    }
    if (state == ConnectionState.disconnected ||
        state == ConnectionState.error) {
      _initialized = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectScheduled || !_canConnect) return;
    _reconnectScheduled = true;
    final delaySec = _reconnectBackoffSeconds;
    Future<void>.delayed(Duration(seconds: delaySec), () async {
      _reconnectScheduled = false;
      if (!_canConnect) return;
      try {
        await _resubscribeAll();
        _reconnectBackoffSeconds = 2;
      } catch (e) {
        _reconnectBackoffSeconds = (_reconnectBackoffSeconds * 2).clamp(
          2,
          _maxReconnectBackoffSeconds,
        );
        if (kDebugMode) {
          debugPrint('Reverb reconnect failed: $e');
        }
        _scheduleReconnect();
      }
    });
  }

  Future<void> _resubscribeAll() async {
    final notificationSnapshot =
        Map<int, List<VoidCallback>>.from(_notificationListeners);
    final conversationSnapshot =
        Map<int, _ConversationHandlers>.from(_conversationHandlers);

    // [ReverbClient] keeps channels by name. If we only call [Channel.unsubscribe],
    // the stale instance stays in the client map and [subscribeToPrivateChannel]
    // returns it without calling [subscribe] again — no events until app restart.
    for (final channel in List<Channel>.from(_channels.values)) {
      _client.unsubscribeFromChannel(channel.name);
    }
    for (final channel in List<Channel>.from(_notificationChannels.values)) {
      _client.unsubscribeFromChannel(channel.name);
    }
    _channels.clear();
    _notificationChannels.clear();
    // Otherwise [subscribeToConversation] hits `existing != null` and skips wiring.
    _conversationHandlers.clear();
    _initialized = false;

    await connect();

    for (final entry in notificationSnapshot.entries) {
      for (final listener in entry.value) {
        await subscribeToNotificationUpdates(entry.key, listener);
      }
    }

    for (final entry in conversationSnapshot.entries) {
      final handlers = entry.value;
      await subscribeToConversation(
        entry.key,
        handlers.onMessage,
        onAssistantStream: handlers.onAssistantStream,
      );
    }
  }

  /// Disconnect (e.g. on logout).
  void disconnect() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _reconnectScheduled = false;
    _reconnectBackoffSeconds = 2;
    for (final c in _channels.values) {
      c.unsubscribe();
    }
    for (final c in _notificationChannels.values) {
      c.unsubscribe();
    }
    _channels.clear();
    _conversationHandlers.clear();
    _notificationChannels.clear();
    _notificationListeners.clear();
    _client.disconnect();
    _initialized = false;
  }

  Future<void> subscribeToNotificationUpdates(
    int userId,
    VoidCallback onUpdate,
  ) async {
    if (!_canConnect) return;

    final listeners = _notificationListeners.putIfAbsent(userId, () => []);
    if (!listeners.contains(onUpdate)) {
      listeners.add(onUpdate);
    }

    if (_notificationChannels.containsKey(userId)) return;

    if (!_initialized) await connect();

    final channelName = 'private-notifications.$userId';
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
      _client.unsubscribeFromChannel(channel.name);
    }
  }

  Future<void> subscribeToConversation(
    int conversationId,
    void Function(Map<String, dynamic> payload) onMessage, {
    void Function(Map<String, dynamic> payload)? onAssistantStream,
  }) async {
    if (!_canConnect) return;

    final existing = _conversationHandlers[conversationId];
    if (existing != null) {
      existing.onMessage = onMessage;
      existing.onAssistantStream = onAssistantStream;
      if (_channels.containsKey(conversationId)) {
        return;
      }
    } else {
      _conversationHandlers[conversationId] = _ConversationHandlers(
        onMessage: onMessage,
        onAssistantStream: onAssistantStream,
      );
    }

    final handlers = _conversationHandlers[conversationId]!;

    if (!_initialized) await connect();

    final channelName = 'private-conversation.$conversationId';
    final channel = _client.subscribeToPrivateChannel(channelName);

    void handleEvent(String eventName, dynamic data) {
      final payload = _coercePayload(data);
      if (payload != null) {
        handlers.onMessage(payload);
      }
    }

    void handleAssistantStream(String eventName, dynamic data) {
      final handler = handlers.onAssistantStream;
      if (handler == null) return;
      final payload = _coercePayload(data);
      if (payload != null) {
        handler(payload);
      }
    }

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

  Future<void> unsubscribeFromConversation(int conversationId) async {
    _conversationHandlers.remove(conversationId);
    final channel = _channels.remove(conversationId);
    if (channel != null) {
      _client.unsubscribeFromChannel(channel.name);
    }
  }

  Stream<ConnectionState> get connectionState =>
      _client.onConnectionStateChange;
}
