import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../config/api_config.dart';
import 'api_client.dart';

/// Keeps a lesson's discussion feed live while its screen is open: connects to
/// the shared chat Socket.IO server and listens for `lesson_discussion` push
/// events scoped to this lesson, refetching just the discussion feed when one
/// arrives. Falls back to polling on a timer if the socket can't connect or
/// drops, so the feed still updates (just less instantly) without realtime.
class LessonDiscussionRealtime {
  final ApiClient client;
  final int lessonId;
  final void Function(List<Map<String, dynamic>> discussion) onUpdate;

  socket_io.Socket? _socket;
  Timer? _pollTimer;
  bool _disposed = false;

  LessonDiscussionRealtime({
    required this.client,
    required this.lessonId,
    required this.onUpdate,
  });

  Future<void> start() async {
    try {
      final token = await client.getChatSocketToken();
      if (_disposed) return;
      _connect(token);
    } catch (_) {
      if (_disposed) return;
      _startPolling();
    }
  }

  void _connect(String token) {
    final socket = socket_io.io(
      ApiConfig.chatSocketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) => _stopPolling());
    socket.onConnectError((_) => _startPolling());
    socket.onDisconnect((_) => _startPolling());
    socket.on('notification', (data) {
      if (data is! Map) return;
      if ('${data['domain']}' != 'lesson_discussion') return;
      final eventLessonId = data['lessonId'];
      final matches = eventLessonId is num
          ? eventLessonId.toInt() == lessonId
          : int.tryParse('$eventLessonId') == lessonId;
      if (matches) _refresh();
    });
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 7), (_) => _refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refresh() async {
    try {
      final discussion = await client.getLessonDiscussionFeed(lessonId);
      if (_disposed) return;
      onUpdate(discussion);
    } catch (_) {
      // Best-effort — the next event/poll tick will retry.
    }
  }

  void dispose() {
    _disposed = true;
    _stopPolling();
    _socket?.dispose();
    _socket = null;
  }
}
