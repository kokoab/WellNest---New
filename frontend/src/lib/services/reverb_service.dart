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

  Future<Map<String, String>> _authorizer(String channelName, String socketId) async {
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
    _channels.clear();
    _client.disconnect();
    _initialized = false;
  }

  /// Subscribe to new messages in a conversation. [onMessage] receives the payload from the backend (map with 'message' key).
  /// Call [unsubscribeFromConversation] when leaving the conversation screen.
  Future<void> subscribeToConversation(
    int conversationId,
    void Function(Map<String, dynamic> payload) onMessage,
  ) async {
    if (_channels.containsKey(conversationId)) return;
    if (!_initialized) await connect();

    final channelName = 'private-conversation.$conversationId';
    final channel = _client.subscribeToPrivateChannel(channelName);
    channel.bind('message.new', (String eventName, dynamic data) {
      if (data is Map<String, dynamic>) {
        onMessage(data);
      }
    });
    _channels[conversationId] = channel;
  }

  /// Unsubscribe from a conversation channel (call when leaving the chat screen).
  Future<void> unsubscribeFromConversation(int conversationId) async {
    final channel = _channels.remove(conversationId);
    if (channel != null) {
      await channel.unsubscribe();
    }
  }

  /// Optional: expose connection state for UI (e.g. "Live" / "Reconnecting").
  Stream<ConnectionState> get connectionState => _client.onConnectionStateChange;
}
