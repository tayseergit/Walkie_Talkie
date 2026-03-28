import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;

class TcpSocketDataSource {
  Socket? _clientSocket;
  ServerSocket? _serverSocket;
  
  // Pipeline allowing the repository to bind bytes linearly to the playback subsystem
  final _incomingAudioController = StreamController<Uint8List>.broadcast();
  // Simple health ping pipeline
  final _connectionStatusController = StreamController<bool>.broadcast();

  Stream<Uint8List> get incomingAudioStream => _incomingAudioController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Initiate direct client connection (Supports future dynamic IP discovery)
  Future<void> connectAsClient(String ip, int port) async {
    try {
      _clientSocket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _connectionStatusController.add(true);
      developer.log('TCP Socket connected to host stream at $ip:$port', name: 'TcpSocketDataSource');

      _clientSocket!.listen(
        (data) => _incomingAudioController.add(Uint8List.fromList(data)),
        onError: (error) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );
    } catch (e) {
      developer.log('Stream connection failed: $e', name: 'TcpSocketDataSource');
      _connectionStatusController.add(false);
      throw Exception('Failed to connect: $e');
    }
  }

  /// Expose hardware port dynamically specifically listening for fast audio chunks
  Future<void> startServer(int port) async {
    if (_serverSocket != null) return;
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      developer.log('Audio pipe initialized openly on port $port', name: 'TcpSocketDataSource');

      _serverSocket!.listen((Socket client) {
        _clientSocket = client; // Bind purely to this sender
        _connectionStatusController.add(true);
        developer.log('Active audio sender hooked.', name: 'TcpSocketDataSource');

        client.listen(
          (data) => _incomingAudioController.add(Uint8List.fromList(data)),
          onError: (error) => _handleDisconnect(),
          onDone: () => _handleDisconnect(),
        );
      });
    } catch (e) {
      developer.log('Failed to start TCP pipeline: $e', name: 'TcpSocketDataSource');
      throw Exception('Server start failed: $e');
    }
  }

  /// Fire raw audio chunks through the wire
  void sendAudioChunk(Uint8List chunk) {
    if (_clientSocket != null) {
      try {
        _clientSocket!.add(chunk);
      } catch (e) {
        developer.log('Audio chunk drop detected: $e', name: 'TcpSocketDataSource');
        _handleDisconnect();
      }
    }
  }

  void _handleDisconnect() {
    _connectionStatusController.add(false);
    disconnect();
  }

  Future<void> disconnect() async {
    await _clientSocket?.close();
    _clientSocket = null;
    developer.log('Terminated target socket', name: 'TcpSocketDataSource');
  }

  Future<void> closeServer() async {
    await _serverSocket?.close();
    _serverSocket = null;
    developer.log('Closed listening pipeline', name: 'TcpSocketDataSource');
  }
}
