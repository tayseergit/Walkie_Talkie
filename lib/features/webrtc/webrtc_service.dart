import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Wraps a single RTCPeerConnection for 1-to-1 LAN audio.
///
/// Flow:
///   Host  → [initialize] → [createOffer]   → exchange SDP/ICE via WS
///   Client → [initialize] → [createAnswer] → exchange SDP/ICE via WS
///
/// PTT: [startTalking] / [stopTalking] enables/disables the local audio track.
/// Bluetooth: [Helper.setSpeakerphoneOn(false)] routes audio to earpiece / BT headset.
class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _audioSessionReady = false;

  final _iceController = StreamController<RTCIceCandidate>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  /// Emits local ICE candidates – relay these via WS to the peer.
  Stream<RTCIceCandidate> get iceStream => _iceController.stream;

  /// True when the WebRTC P2P link is established and audio can flow.
  Stream<bool> get connectionStream => _connectedController.stream;

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

  /// Creates the RTCPeerConnection and wires up all callbacks.
  Future<void> _createPc() async {
    await _configureAudioSession();
    await _pc?.close();
    _pc = await createPeerConnection(_iceConfig);

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) _iceController.add(candidate);
    };

    _pc!.onConnectionState = (state) {
      final active = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _connectedController.add(active);
    };

    // Remote audio track is rendered automatically by flutter_webrtc
    _pc!.onTrack = (event) {};

    // Add local mic track (muted) to the connection
    for (final track in _localStream!.getAudioTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
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

  /// HOST: creates and returns an SDP offer. Set [setLocalDescription] internally.
  Future<RTCSessionDescription> createOffer() async {
    await _createPc();
    final offer = await _pc!.createOffer({'offerToReceiveAudio': 1});
    await _pc!.setLocalDescription(offer);
    return offer;
  }

  /// CLIENT: takes the host's offer, creates an answer.
  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await _createPc();
    await _pc!.setRemoteDescription(offer);
    final answer = await _pc!.createAnswer({'offerToReceiveAudio': 1});
    await _pc!.setLocalDescription(answer);
    return answer;
  }

  /// HOST: call after receiving the client's SDP answer via WS.
  Future<void> setRemoteAnswer(RTCSessionDescription answer) async {
    await _pc!.setRemoteDescription(answer);
  }

  /// Add a remote ICE candidate forwarded via WS.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _pc?.addCandidate(candidate);
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
    await _pc?.close();
    _pc = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    _localStream = null;
    _audioSessionReady = false;
  }
}
