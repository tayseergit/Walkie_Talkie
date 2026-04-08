import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsServer {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {};
  final Map<WebSocketChannel, String> _socketToDeviceId = {};
  final Map<String, String> _clientIps = {};

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _clientsController = StreamController<List<Map<String, String>>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<List<Map<String, String>>> get clientsStream => _clientsController.stream;

  List<Map<String, String>> get clients => _clients.keys
      .map(
        (id) => {
          'id': id,
          'ip': _clientIps[id] ?? '',
        },
      )
      .toList();

  Future<void> start({int port = 8765}) async {
    if (_server != null) return;

    final handler = webSocketHandler(
      (WebSocketChannel socket, String? protocol) {
        socket.stream.listen(
          (data) {
            try {
              final msg =
                  jsonDecode(data as String) as Map<String, dynamic>;
              _handleMessage(socket, msg);
            } catch (_) {}
          },
          onDone: () => _handleClientGone(socket),
          onError: (_) => _handleClientGone(socket),
        );
      },
    );

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  void _handleMessage(WebSocketChannel socket, Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;

    if (type == 'join') {
      final from = (msg['from'] as String?) ?? (msg['deviceId'] as String?);
      if (from == null || from.isEmpty) return;
      final data = msg['data'];
      final ip = data is Map<String, dynamic> ? (data['ip'] as String? ?? '') : '';

      _clients[from] = socket;
      _socketToDeviceId[socket] = from;
      _clientIps[from] = ip;
      _broadcastClients();
      _messageController.add(msg);
      return;
    }

    if (type == 'offer' || type == 'answer' || type == 'ice') {
      final to = msg['to'] as String?;
      if (to == null) return;
      final target = _clients[to];
      if (target != null) {
        target.sink.add(jsonEncode(msg));
      }
      return;
    }

    if (type == 'lock' || type == 'unlock') {
      _broadcast(msg);
      return;
    }

    _messageController.add(msg);
  }

  void _handleClientGone(WebSocketChannel socket) {
    final id = _socketToDeviceId.remove(socket);
    if (id != null) {
      _clients.remove(id);
      _clientIps.remove(id);
      _broadcastClients();
    }
  }

  void _broadcastClients() {
    final payload = {
      'type': 'clients',
      'data': clients,
    };
    _broadcast(payload);
    _clientsController.add(clients);
  }

  void _broadcast(Map<String, dynamic> message) {
    final raw = jsonEncode(message);
    for (final socket in _clients.values) {
      socket.sink.add(raw);
    }
  }

  Future<void> stop() async {
    for (final socket in _clients.values) {
      await socket.sink.close();
    }
    _clients.clear();
    _clientIps.clear();
    _socketToDeviceId.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
