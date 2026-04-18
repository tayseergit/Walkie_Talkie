import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/ws_client.dart';
import '../../data/ws_server.dart';
import '../../domain/models/peer_info.dart';
import '../../domain/models/room_model.dart';
import '../../../webrtc/webrtc_service.dart';

class RoomCubit extends Cubit<RoomState> {
  final WsServer _wsServer = WsServer();
  final WsClient _wsClient = WsClient();
  final WebRtcService _webRtc = WebRtcService();
  final NetworkInfo _networkInfo = NetworkInfo();
  final List<StreamSubscription> _subs = [];
  
  final Set<String> _connectedPeerIds = {};
  final Set<String> _selectedPeerIds = {};
  final Map<String, ConnectionStatus> _connectionStates = {};
  final Set<String> _peerTalkingIds = {};

  bool _isHost = false;
  String _myName = 'Device';
  late String _myId;
  String? _myIp;
  bool _isTalkingLocally = false;
  String? _wsUrl;

  RoomCubit() : super(const RoomIdle()) {
    _myId = _newDeviceId(_myName);
    _listenWebRtcStreams();
  }

  String _newDeviceId(String seed) {
    final clean = seed.trim().isEmpty
        ? 'device'
        : seed.trim().replaceAll(' ', '_');
    final tail = DateTime.now().millisecondsSinceEpoch % 100000;
    final rnd = Random().nextInt(900) + 100;
    return '$clean-$tail$rnd';
  }

  void _emitActiveState([List<PeerInfo>? clientsOverride]) {
    final cur = state;
    if (cur is RoomActive) {
      emit(
        cur.copyWith(
          connectedPeers: _connectedPeerIds.toSet(),
          selectedPeers: _selectedPeerIds.toSet(),
          connectionStates: Map.from(_connectionStates),
          isTalking: _isTalkingLocally,
          peerTalking: _peerTalkingIds.isNotEmpty,
          clients: clientsOverride ?? cur.clients,
        ),
      );
    }
  }

  Future<void> hostRoom(String name) async {
    _myName = name.isEmpty ? 'Host' : name;
    _myId = _newDeviceId(_myName);
    _isHost = true;

    final ip = await _networkInfo.getWifiIP();
    if (ip == null) {
      emit(const RoomError('Could not determine local IP. Are you on Wi-Fi?'));
      return;
    }
    _myIp = ip;

    await _wsServer.start(port: 8765);
    _wsUrl = 'ws://$ip:8765';
    emit(RoomHosting(wsUrl: _wsUrl!, myIp: ip, myName: _myName));

    _subs.add(
      _wsServer.clientsStream.listen((rawClients) {
        if (state is! RoomHosting) return;
        final clients = rawClients
            .map((c) => PeerInfo(name: c['id'] ?? 'unknown', ip: c['ip'] ?? ''))
            .toList();
        emit((state as RoomHosting).copyWith(clients: clients));
      }),
    );
  }

  void startJoining(String name) {
    _myName = name.isEmpty ? 'Client' : name;
    _myId = _newDeviceId(_myName);
    _isHost = false;
    emit(RoomScanning(myName: _myName));
  }

  Future<void> joinRoom(String wsUrl) async {
    try {
      await _wsClient.connect(wsUrl);
    } catch (e) {
      emit(RoomError('Could not connect: $e'));
      return;
    }

    _myIp = await _networkInfo.getWifiIP();

    _subs.add(_wsClient.messages.listen(_handleClientMessage));
    _subs.add(
      _wsClient.onClosed.listen((_) async {
        await _cleanupWebRtc();
        emit(const RoomClosed('Disconnected from room host.'));
      }),
    );

    emit(
      RoomActive(
        isHost: false,
        myId: _myId,
        clients: const [],
      ),
    );
    _wsClient.send({
      'type': 'join',
      'from': _myId,
      'to': 'host',
      'data': {'ip': _myIp ?? '', 'name': _myName},
    });
  }

  void _handleClientMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'clients':
        final data = msg['data'] as List<dynamic>? ?? const [];
        final peers = data
            .whereType<Map<String, dynamic>>()
            .map(
              (c) => PeerInfo(
                name: c['id'] as String? ?? 'unknown',
                ip: c['ip'] as String? ?? '',
              ),
            )
            .where((p) => p.name != _myId)
            .toList();
        
        if (state is RoomActive) {
          final availableIds = peers.map((p) => p.name).toSet();
          final stalePeerIds = _webRtc.peerIds
              .where((id) => !availableIds.contains(id))
              .toList();
          for (final staleId in stalePeerIds) {
            await _disconnectPeer(staleId, notifyUnlock: false);
          }
          _emitActiveState(peers);
        }
        return;

      case 'offer':
        await _acceptIncomingOffer(msg);
        return;

      case 'answer':
        await _acceptIncomingAnswer(msg);
        return;

      case 'ice':
        await _acceptIncomingIce(msg);
        return;

      case 'lock':
      case 'unlock':
        if (state is RoomActive) {
          final from = msg['from'] as String?;
          if (from != null) {
            if (type == 'lock') {
              _peerTalkingIds.add(from);
            } else {
              _peerTalkingIds.remove(from);
            }
            _emitActiveState();
          }
        }
        return;
    }
  }

  void togglePeerSelection(String peerId) {
    if (_selectedPeerIds.contains(peerId)) {
      _selectedPeerIds.remove(peerId);
    } else {
      _selectedPeerIds.add(peerId);
    }
    _emitActiveState();
    
    if (_isTalkingLocally) {
      _webRtc.updateTalking(true, _selectedPeerIds);
    }
  }

  Future<void> callPeer(PeerInfo target) async {
    if (_isHost || state is! RoomActive) return;
    if (target.name == _myId) return;

    if (_webRtc.hasPeer(target.name)) {
      await _disconnectPeer(target.name);
      _emitActiveState();
      return;
    }

    if (!await Permission.microphone.request().isGranted) {
      emit(const RoomError('Microphone permission denied.'));
      return;
    }

    _connectionStates[target.name] = ConnectionStatus.connecting;
    _emitActiveState();

    await _webRtc.initialize();
    final offer = await _webRtc.createOffer(target.name);
    _wsClient.send({
      'type': 'offer',
      'from': _myId,
      'to': target.name,
      'data': {'sdp': offer.sdp},
    });
  }

  Future<void> _acceptIncomingOffer(Map<String, dynamic> msg) async {
    if (_isHost || state is! RoomActive) return;
    if (!await Permission.microphone.request().isGranted) {
      emit(const RoomError('Microphone permission denied.'));
      return;
    }

    final from = msg['from'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;
    final sdp = data?['sdp'] as String?;
    if (from == null || sdp == null) return;

    _connectionStates[from] = ConnectionStatus.connecting;
    _emitActiveState();

    await _webRtc.initialize();

    final offer = RTCSessionDescription(sdp, 'offer');
    final answer = await _webRtc.createAnswer(from, offer);
    _wsClient.send({
      'type': 'answer',
      'from': _myId,
      'to': from,
      'data': {'sdp': answer.sdp},
    });
  }

  Future<void> _acceptIncomingAnswer(Map<String, dynamic> msg) async {
    final from = msg['from'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;
    final sdp = data?['sdp'] as String?;
    if (from == null || sdp == null) return;
    await _webRtc.setRemoteAnswer(from, RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _acceptIncomingIce(Map<String, dynamic> msg) async {
    final from = msg['from'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;
    if (from == null || data == null) return;
    final candidate = data['candidate'] as String?;
    if (candidate == null) return;
    await _webRtc.addIceCandidate(
      from,
      RTCIceCandidate(
        candidate,
        data['sdpMid'] as String?,
        data['sdpMLineIndex'] as int?,
      ),
    );
  }

  void _listenWebRtcStreams() {
    _subs.add(
      _webRtc.iceStream.listen((event) {
        if (_isHost || !_wsClient.isConnected) return;
        _wsClient.send({
          'type': 'ice',
          'from': _myId,
          'to': event.peerId,
          'data': {
            'candidate': event.candidate.candidate,
            'sdpMid': event.candidate.sdpMid,
            'sdpMLineIndex': event.candidate.sdpMLineIndex,
          },
        });
      }),
    );

    _subs.add(
      _webRtc.connectionStream.listen((event) {
        if (event.isConnected) {
          _connectedPeerIds.add(event.peerId);
          _selectedPeerIds.add(event.peerId); 
          _connectionStates[event.peerId] = ConnectionStatus.connected;
        } else {
          _connectedPeerIds.remove(event.peerId);
          _selectedPeerIds.remove(event.peerId);
          _connectionStates[event.peerId] = ConnectionStatus.disconnected;
          _peerTalkingIds.remove(event.peerId);
        }

        if (state is RoomActive) {
          _emitActiveState();
        }
      }),
    );
  }

  void pressedPtt() {
    if (state is! RoomActive) return;
    if (_connectedPeerIds.intersection(_selectedPeerIds).isEmpty) return;
    if (_peerTalkingIds.isNotEmpty) return; 

    _isTalkingLocally = true;
    _webRtc.updateTalking(true, _selectedPeerIds);
    
    for (var targetId in _selectedPeerIds.intersection(_connectedPeerIds)) {
      _wsClient.send({
        'type': 'lock',
        'from': _myId,
        'to': targetId,
        'data': null,
      });
    }
    _emitActiveState();
  }

  void releasedPtt() {
    if (!_isTalkingLocally || state is! RoomActive) return;

    _isTalkingLocally = false;
    _webRtc.updateTalking(false, _selectedPeerIds);

    for (var targetId in _selectedPeerIds.intersection(_connectedPeerIds)) {
      _wsClient.send({
        'type': 'unlock',
        'from': _myId,
        'to': targetId,
        'data': null,
      });
    }
    _emitActiveState();
  }

  Future<void> disconnect() async {
    await _cleanupWebRtc();
    if (_isHost) {
      await _wsServer.stop();
    } else {
      await _wsClient.disconnect();
    }
    if (!isClosed) emit(const RoomIdle());
  }

  Future<void> _cleanupWebRtc() async {
    await _webRtc.dispose();
    _connectedPeerIds.clear();
    _selectedPeerIds.clear();
    _connectionStates.clear();
    _peerTalkingIds.clear();
    _isTalkingLocally = false;
  }

  Future<void> _disconnectPeer(
    String peerId, {
    bool notifyUnlock = true,
  }) async {
    if (_isTalkingLocally && _selectedPeerIds.contains(peerId)) {
      if (notifyUnlock && _wsClient.isConnected) {
        _wsClient.send({
          'type': 'unlock',
          'from': _myId,
          'to': peerId,
          'data': null,
        });
      }
    }

    await _webRtc.closePeer(peerId);
    _connectedPeerIds.remove(peerId);
    _selectedPeerIds.remove(peerId);
    _connectionStates[peerId] = ConnectionStatus.disconnected;
    _peerTalkingIds.remove(peerId);
  }

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _cleanupWebRtc();
    await _wsServer.stop();
    await _wsClient.disconnect();
    return super.close();
  }
}
