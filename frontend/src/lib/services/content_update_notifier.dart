import 'package:flutter/foundation.dart';

enum ContentUpdateKind { recipe, post }

enum ContentUpdateAction { likeChanged, saveChanged }

class ContentUpdate {
  final ContentUpdateKind kind;
  final ContentUpdateAction action;
  final int id;
  final bool isActive;

  const ContentUpdate({
    required this.kind,
    required this.action,
    required this.id,
    required this.isActive,
  });
}

/// Lightweight in-process event bus for user-triggered content changes.
///
/// This does not poll. Services publish only after a successful API mutation,
/// and visible/kept-alive screens decide how to update their local state.
class ContentUpdateNotifier extends ChangeNotifier {
  ContentUpdateNotifier._();

  static final ContentUpdateNotifier instance = ContentUpdateNotifier._();

  ContentUpdate? _lastUpdate;
  int _version = 0;

  ContentUpdate? get lastUpdate => _lastUpdate;
  int get version => _version;

  void publish(ContentUpdate update) {
    _lastUpdate = update;
    _version++;
    notifyListeners();
  }
}
