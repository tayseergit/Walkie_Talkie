import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class PeerIceCandidateEvent {
  final String peerId;
  final RTCIceCandidate candidate;

  const PeerIceCandidateEvent({required this.peerId, required this.candidate});
}

class PeerConnectionEvent {
  final String peerId;
  final bool isConnected;

  const PeerConnectionEvent({required this.peerId, required this.isConnected});
}

/// Manages RTCPeerConnections for LAN audio calls (one PC per remote peer).
///
/// Flow:
///   Host  → [initialize] → [createOffer]   → exchange SDP/ICE via WS
///   Client → [initialize] → [createAnswer] → exchange SDP/ICE via WS
///
/// PTT: [startTalking] / [stopTalking] enables/disables the local audio track.
/// Bluetooth: [Helper.setSpeakerphoneOn(false)] routes audio to earpiece / BT headset.
class WebRtcService {
  final Map<String, RTCPeerConnection> _peers = {};
  MediaStream? _localStream;
  bool _audioSessionReady = false;

  final _iceController = StreamController<PeerIceCandidateEvent>.broadcast();
  final _connectedController =
      StreamController<PeerConnectionEvent>.broadcast();

  /// Emits local ICE candidates – relay these via WS to the peer.
  Stream<PeerIceCandidateEvent> get iceStream => _iceController.stream;

  /// True when the WebRTC P2P link is established and audio can flow.
  Stream<PeerConnectionEvent> get connectionStream =>
      _connectedController.stream;

  Set<String> get peerIds => _peers.keys.toSet();

  bool hasPeer(String peerId) => _peers.containsKey(peerId);

  // LAN-only config: no STUN/TURN needed
  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [],
    'sdpSemantics': 'unified-plan',
  };

  /// Acquires the local microphone and sets audio routing for BT.
  /// Call this before [createOffer] or [createAnswer].
  Future<void> initialize() async {
    await _configureAudioSession();
    if (_localStream != null) return;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    // Mic starts muted — unmuted only while PTT is held
    _setMicEnabled(false);

    // Route received audio to earpiece / connected BT headset (not loudspeaker)
    // On Android this sets MODE_IN_COMMUNICATION which enables BT SCO if available.
    await Helper.setSpeakerphoneOn(false);
  }

  /// Creates/reuses one RTCPeerConnection per peer and wires up callbacks.
  Future<RTCPeerConnection> _ensurePeerConnection(String peerId) async {
    final existing = _peers[peerId];
    if (existing != null) return existing;

    await _configureAudioSession();
    final pc = await createPeerConnection(_iceConfig);

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _iceController.add(
          PeerIceCandidateEvent(peerId: peerId, candidate: candidate),
        );
      }
    };

    pc.onConnectionState = (state) {
      final active =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _connectedController.add(
        PeerConnectionEvent(peerId: peerId, isConnected: active),
      );
    };

    // Remote audio track is rendered automatically by flutter_webrtc
    pc.onTrack = (event) {};

    // Reuse same local mic stream across all peers.
    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    _peers[peerId] = pc;
    return pc;
  }

  Future<void> _configureAudioSession() async {
    if (_audioSessionReady) return;
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
    await session.setActive(true);
    _audioSessionReady = true;
  }

  /// Creates and returns an SDP offer for a specific peer.
  Future<RTCSessionDescription> createOffer(String peerId) async {
    final pc = await _ensurePeerConnection(peerId);
    final offer = await pc.createOffer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(offer);
    return offer;
  }

  /// Takes a remote offer from [peerId] and creates an answer.
  Future<RTCSessionDescription> createAnswer(
    String peerId,
    RTCSessionDescription offer,
  ) async {
    final pc = await _ensurePeerConnection(peerId);
    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer({'offerToReceiveAudio': 1});
    await pc.setLocalDescription(answer);
    return answer;
  }

  /// Call after receiving the peer's SDP answer via WS.
  Future<void> setRemoteAnswer(
    String peerId,
    RTCSessionDescription answer,
  ) async {
    final pc = _peers[peerId];
    if (pc == null) return;
    await pc.setRemoteDescription(answer);
  }

  /// Add a remote ICE candidate forwarded via WS.
  Future<void> addIceCandidate(String peerId, RTCIceCandidate candidate) async {
    final pc = _peers[peerId];
    if (pc == null) return;
    await pc.addCandidate(candidate);
  }

  Future<void> closePeer(String peerId) async {
    final pc = _peers.remove(peerId);
    if (pc == null) return;
    await pc.close();
    _connectedController.add(
      PeerConnectionEvent(peerId: peerId, isConnected: false),
    );
  }

  void _setMicEnabled(bool enabled) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  /// Un-mutes the mic: audio starts flowing to the remote peer.
  void startTalking() => _setMicEnabled(true);

  /// Mutes the mic: audio stops.
  void stopTalking() => _setMicEnabled(false);

  Future<void> dispose() async {
    _setMicEnabled(false);
    for (final pc in _peers.values) {
      await pc.close();
    }
    _peers.clear();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    _audioSessionReady = false;
  }
}
