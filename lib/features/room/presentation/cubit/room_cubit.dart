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

  bool _isHost = false;
  String _myName = 'Device';
  late String _myId;
  String? _myIp;
  String? _activeTargetId;
  String? _wsUrl;

  RoomCubit() : super(const RoomIdle()) {
    _myId = _newDeviceId(_myName);
    _listenWebRtcStreams();
  }

  String _newDeviceId(String seed) {
    final clean = seed.trim().isEmpty ? 'device' : seed.trim().replaceAll(' ', '_');
    final tail = DateTime.now().millisecondsSinceEpoch % 100000;
    final rnd = Random().nextInt(900) + 100;
    return '$clean-$tail$rnd';
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
    _subs.add(_wsClient.onClosed.listen((_) async {
      await _cleanupWebRtc();
      emit(const RoomClosed('Disconnected from room host.'));
    }));

    emit(RoomActive(isHost: false, myId: _myId, clients: const []));
    _wsClient.send({
      'type': 'join',
      'from': _myId,
      'to': 'host',
      'data': {
        'ip': _myIp ?? '',
        'name': _myName,
      },
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
          var active = state as RoomActive;
          final selected = active.selectedPeer;
          final selectedStillExists = selected != null && peers.any((p) => p.name == selected.name);
          active = active.copyWith(
            clients: peers,
            selectedPeer: selectedStillExists ? selected : null,
            isConnected: selectedStillExists ? active.isConnected : false,
            isTalking: selectedStillExists ? active.isTalking : false,
            peerTalking: selectedStillExists ? active.peerTalking : false,
          );
          if (!selectedStillExists) {
            _activeTargetId = null;
          }
          emit(active);
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
          if (from != null && from == _activeTargetId) {
            emit((state as RoomActive).copyWith(peerTalking: type == 'lock'));
          }
        }
        return;
    }
  }

  Future<void> callPeer(PeerInfo target) async {
    if (_isHost || state is! RoomActive) return;
    if (target.name == _myId) return;
    if (!await Permission.microphone.request().isGranted) {
      emit(const RoomError('Microphone permission denied.'));
      return;
    }

    _activeTargetId = target.name;
    final cur = state as RoomActive;
    emit(cur.copyWith(
      selectedPeer: target,
      isConnected: false,
      isTalking: false,
      peerTalking: false,
    ));

    await _cleanupWebRtc();
    await _webRtc.initialize();
    final offer = await _webRtc.createOffer();
    _wsClient.send({
      'type': 'offer',
      'from': _myId,
      'to': target.name,
      'data': {
        'sdp': offer.sdp,
      },
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

    _activeTargetId = from;
    final peers = (state as RoomActive).clients;
    final matches = peers.where((p) => p.name == from);
    final peer = matches.isNotEmpty ? matches.first : PeerInfo(name: from, ip: '');

    emit((state as RoomActive).copyWith(
      selectedPeer: peer,
      isConnected: false,
      isTalking: false,
      peerTalking: false,
    ));

    await _cleanupWebRtc();
    await _webRtc.initialize();

    final offer = RTCSessionDescription(sdp, 'offer');
    final answer = await _webRtc.createAnswer(offer);
    _wsClient.send({
      'type': 'answer',
      'from': _myId,
      'to': from,
      'data': {
        'sdp': answer.sdp,
      },
    });
  }

  Future<void> _acceptIncomingAnswer(Map<String, dynamic> msg) async {
    final from = msg['from'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;
    final sdp = data?['sdp'] as String?;
    if (from == null || sdp == null || from != _activeTargetId) return;
    await _webRtc.setRemoteAnswer(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _acceptIncomingIce(Map<String, dynamic> msg) async {
    final from = msg['from'] as String?;
    final data = msg['data'] as Map<String, dynamic>?;
    if (from == null || data == null || from != _activeTargetId) return;
    final candidate = data['candidate'] as String?;
    if (candidate == null) return;
    await _webRtc.addIceCandidate(
      RTCIceCandidate(
        candidate,
        data['sdpMid'] as String?,
        data['sdpMLineIndex'] as int?,
      ),
    );
  }

  void _listenWebRtcStreams() {
    _subs.add(_webRtc.iceStream.listen((candidate) {
      if (_isHost || !_wsClient.isConnected || _activeTargetId == null) return;
      _wsClient.send({
        'type': 'ice',
        'from': _myId,
        'to': _activeTargetId,
        'data': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    }));

    _subs.add(_webRtc.connectionStream.listen((connected) {
      if (state is! RoomActive) return;
      final cur = state as RoomActive;
      emit(cur.copyWith(
        isConnected: connected,
        isTalking: connected ? cur.isTalking : false,
        peerTalking: connected ? cur.peerTalking : false,
      ));
    }));
  }

  void pressedPtt() {
    final cur = state;
    if (cur is! RoomActive) return;
    if (!cur.isConnected || cur.peerTalking || cur.isTalking || _activeTargetId == null) return;

    _webRtc.startTalking();
    _wsClient.send({
      'type': 'lock',
      'from': _myId,
      'to': _activeTargetId,
      'data': null,
    });
    emit(cur.copyWith(isTalking: true));
  }

  void releasedPtt() {
    final cur = state;
    if (cur is! RoomActive || !cur.isTalking || _activeTargetId == null) return;

    _webRtc.stopTalking();
    _wsClient.send({
      'type': 'unlock',
      'from': _myId,
      'to': _activeTargetId,
      'data': null,
    });
    emit(cur.copyWith(isTalking: false));
  }

  Future<void> disconnect() async {
    await _cleanupWebRtc();
    _activeTargetId = null;
    if (_isHost) {
      await _wsServer.stop();
    } else {
      await _wsClient.disconnect();
    }
    if (!isClosed) emit(const RoomIdle());
  }

  Future<void> _cleanupWebRtc() async {
    await _webRtc.dispose();
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
