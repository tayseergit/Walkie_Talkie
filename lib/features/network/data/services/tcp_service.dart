import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

class TcpService {
  ServerSocket? _serverSocket;
  final int port = 5000;

  /// Starts the TCP server to listen for incoming connections
  Future<void> startServer() async {
    try {
      if (_serverSocket != null) return;
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      developer.log('TCP Server started on port $port', name: 'TcpService');

      _serverSocket!.listen((Socket client) {
        developer.log('Incoming connection from ${client.remoteAddress.address}', name: 'TcpService');
        
        client.listen(
          (List<int> data) {
            final String message = utf8.decode(data).trim();
            developer.log('Received message: $message', name: 'TcpService');

            if (message == 'HELLO') {
              // Send the exact required handshake response
              client.write('OK\n');
              developer.log('Sent response: OK', name: 'TcpService');
            }
          },
          onError: (error) {
            developer.log('Client connection error: $error', name: 'TcpService');
            client.close();
          },
          onDone: () {
            developer.log('Client connection closed', name: 'TcpService');
            client.close();
          },
        );
      });
    } catch (e) {
      developer.log('Failed to start TCP server: $e', name: 'TcpService');
    }
  }

  /// Stops the TCP server
  Future<void> stopServer() async {
    await _serverSocket?.close();
    _serverSocket = null;
    developer.log('TCP Server stopped', name: 'TcpService');
  }

  /// Tests the connection to a specific IP address by expecting a handshake
  Future<bool> testConnection(String ipAddress) async {
    Socket? socket;
    try {
      developer.log('Attempting to connect to $ipAddress:$port', name: 'TcpService');
      
      // 1. Connect with 3-second timeout
      socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 3));
      developer.log('Connected to $ipAddress, sending HELLO...', name: 'TcpService');

      // 2. Send HELLO handshake message
      socket.write('HELLO\n');

      // 3. Wait for the handshake response with timeout
      final completer = Completer<bool>();
      
      socket.listen(
        (List<int> data) {
          final String response = utf8.decode(data).trim();
          developer.log('Received response from $ipAddress: $response', name: 'TcpService');
          if (response == 'OK') {
            if (!completer.isCompleted) completer.complete(true);
          } else {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onError: (error) {
          developer.log('Error receiving from $ipAddress: $error', name: 'TcpService');
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      // Wait up to 2 additional seconds for the handshake response
      final bool isSuccess = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          developer.log('Handshake timeout for $ipAddress', name: 'TcpService');
          return false;
        },
      );

      return isSuccess;
    } catch (e) {
      developer.log('Connection to $ipAddress failed: $e', name: 'TcpService');
      return false; // Safely handled offline state
    } finally {
      // 4. Ensure socket is closed properly and securely
      socket?.destroy();
      developer.log('Socket to $ipAddress destroyed', name: 'TcpService');
    }
  }
}
