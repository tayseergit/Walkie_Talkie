import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client used by the joining device to connect to the host's server.
class WsClient {
  WebSocketChannel? _channel;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _closedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Fires when the WS connection closes (host dropped or kicked).
  Stream<void> get onClosed => _closedController.stream;

  bool get isConnected => _channel != null;

  /// Connects to [wsUrl] (e.g. `ws://192.168.1.5:8765`) and begins listening.
  Future<void> connect(String wsUrl) async {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    // Wait for the underlying handshake to complete
    await _channel!.ready;

    _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _messageController.add(msg);
        } catch (_) {}
      },
      onDone: _handleClose,
      onError: (_) => _handleClose(),
    );
  }

  void _handleClose() {
    _channel = null;
    _closedController.add(null);
  }

  /// Sends a JSON message to the host.
  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
