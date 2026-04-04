import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'network_frame.dart';

class TcpSocketDataSource {
  // Client mapping (Used if acting as Host Hub)
  final Map<String, Socket> _connectedClients = {};
  
  // My active socket (Used if acting as a standard Client Hub node)
  Socket? _clientSocket;
  ServerSocket? _serverSocket;
  
  bool get isHost => _serverSocket != null;

  // Pipeline for audio bytes arriving directly destined to speakers
  final _incomingAudioController = StreamController<Uint8List>.broadcast();
  // Connection ping pipeline
  final _connectionStatusController = StreamController<bool>.broadcast();
  // Connected Devices state sync (List of IPs) globally spanning all networks 
  final _deviceListController = StreamController<List<String>>.broadcast();

  Stream<Uint8List> get incomingAudioStream => _incomingAudioController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<List<String>> get deviceListStream => _deviceListController.stream;

  final TcpStreamParser _parser = TcpStreamParser();

  /// Expose hardware port dynamically expecting multiple client hooks (Host Mode)
  Future<void> startServer(int port) async {
    if (_serverSocket != null) return;
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      developer.log('Hub Server pipe initialized on port $port', name: 'TcpSocketDataSource');

      _serverSocket!.listen((Socket client) {
        final clientIp = client.remoteAddress.address;
        _connectedClients[clientIp] = client;
        
        developer.log('Client hooked to Hub: $clientIp', name: 'TcpSocketDataSource');
        
        _broadcastDeviceList(); // Sync clients whenever someone newly joins the network hub

        final parser = TcpStreamParser();
        client.listen(
          (data) => _processServerData(clientIp, data, parser),
          onError: (error) => _handleClientDisconnect(clientIp),
          onDone: () => _handleClientDisconnect(clientIp),
        );
      });
      // Start of Host is intrinsically "connected" into its own network abstraction
      _connectionStatusController.add(true);
    } catch (e) {
      developer.log('Failed to start Hub pipeline: $e', name: 'TcpSocketDataSource');
      throw Exception('Server start failed: $e');
    }
  }

  void _processServerData(String senderIp, Uint8List data, TcpStreamParser parser) {
    final frames = parser.parseIncomingChunks(data);
    for (final frame in frames) {
      // Hub Routing Engine
      final toId = frame.header['to'] as String?;
      if (toId == null) continue;
      
      // If the packet is destined for the Host itself structurally or globally via "all" 
      if (toId == 'all' || toId == 'host') {
        if (frame.header['type'] == 'audio') {
          _incomingAudioController.add(frame.payload);
        }
      }

      // Re-route dynamically natively out to exactly the targets intended
      if (toId == 'all') {
        // Broadcast to everyone else EXCEPT the sender securely avoiding audio feedback latency looping natively
        final buffer = frame.encode();
        for (var entry in _connectedClients.entries) {
          if (entry.key != senderIp) {
            _safelyWrite(entry.value, buffer, entry.key);
          }
        }
      } else {
        // Targeted routing (CSV of IPs resolving to strict arrays dynamically)
        final buffer = frame.encode();
        final targets = toId.split(',');
        for (var target in targets) {
          final t = target.trim();
          if (_connectedClients.containsKey(t)) {
            _safelyWrite(_connectedClients[t]!, buffer, t);
          }
        }
      }
    }
  }

  void _safelyWrite(Socket socket, Uint8List data, String id) {
    try {
      socket.add(data);
    } catch (e) {
      _handleClientDisconnect(id);
    }
  }

  void _handleClientDisconnect(String ip) {
    _connectedClients[ip]?.close();
    _connectedClients.remove(ip);
    developer.log('Client dropped natively from map: $ip', name: 'TcpSocketDataSource');
    _broadcastDeviceList();
  }

  void _broadcastDeviceList() {
    if (!isHost) return;
    
    // Construct the payload carrying all connected IP addresses seamlessly
    final list = _connectedClients.keys.toList();
    _deviceListController.add(list); // Sync internally immediately to the Host UI natively!
    
    final payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode(list)));
    final dynamicFrame = NetworkFrame(
      header: {'from': 'host', 'to': 'all', 'type': 'control', 'action': 'sync_devices', 'payloadLen': payloadBytes.length},
      payload: payloadBytes, 
    );
    
    final finalBytes = dynamicFrame.encode();
    for (var client in _connectedClients.values) {
      _safelyWrite(client, finalBytes, client.remoteAddress.address);
    }
  }

  /// Initiate direct client connection to a Hub Server dynamically 
  Future<void> connectAsClient(String ip, int port) async {
    try {
      _clientSocket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _connectionStatusController.add(true);
      developer.log('TCP Socket connected to Hub stream explicitly at $ip:$port', name: 'TcpSocketDataSource');

      _clientSocket!.listen(
        (data) => _processClientData(Uint8List.fromList(data)),
        onError: (error) => _handleHostDisconnect(),
        onDone: () => _handleHostDisconnect(),
      );
    } catch (e) {
      developer.log('Hub connection failed natively: $e', name: 'TcpSocketDataSource');
      _connectionStatusController.add(false);
      throw Exception('Failed to connect nicely to Hub: $e');
    }
  }

  void _processClientData(Uint8List data) {
    final frames = _parser.parseIncomingChunks(data);
    for (final frame in frames) {
      final type = frame.header['type'];
      
      if (type == 'audio') {
        _incomingAudioController.add(frame.payload);
      } else if (type == 'control') {
        final action = frame.header['action'];
        if (action == 'sync_devices') {
          // Decode IP array silently synced explicitly from Host hub router 
          try {
            final List<dynamic> ipArray = jsonDecode(utf8.decode(frame.payload));
            final stringList = ipArray.map((e) => e.toString()).toList();
            _deviceListController.add(stringList);
          } catch (_) {}
        }
      }
    }
  }

  /// Fire raw audio chunks securely strictly inside native generic framings
  void sendAudioChunk(Uint8List chunk, {String toId = 'all'}) {
    final frame = NetworkFrame(
      header: {
        'from': _clientSocket != null ? _clientSocket!.address.address : 'host',
        'to': toId,
        'type': 'audio',
        'payloadLen': chunk.length,
      },
      payload: chunk,
    );
    final encoded = frame.encode();

    if (isHost) {
      // Direct Loopback logic (Acting gracefully as Host Server distributing personal audio strictly locally)
      if (toId == 'all') {
        for (var entry in _connectedClients.entries) {
          _safelyWrite(entry.value, encoded, entry.key);
        }
      } else {
        final targets = toId.split(',');
        for (var t in targets) {
          final cleanId = t.trim();
          if (_connectedClients.containsKey(cleanId)) {
            _safelyWrite(_connectedClients[cleanId]!, encoded, cleanId);
          }
        }
      }
    } else if (_clientSocket != null) {
      // Typical client dispatch securely straight towards Hub Router 
      try {
        _clientSocket!.add(encoded);
      } catch (e) {
        _handleHostDisconnect();
      }
    }
  }

  void _handleHostDisconnect() {
    _connectionStatusController.add(false);
    disconnect();
  }

  Future<void> disconnect() async {
    await _clientSocket?.close();
    _clientSocket = null;
    developer.log('Terminated target client architecture definitively', name: 'TcpSocketDataSource');
  }

  Future<void> closeServer() async {
    for (var client in _connectedClients.values) {
      await client.close();
    }
    _connectedClients.clear();
    await _serverSocket?.close();
    _serverSocket = null;
    developer.log('Closed listening pipeline hubs forcefully', name: 'TcpSocketDataSource');
  }
}
