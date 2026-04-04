import 'dart:async';
import 'dart:typed_data';

import '../../domain/entities/audio_device.dart';
import '../../domain/repositories/audio_stream_repository.dart';
import '../datasources/audio_capture_datasource.dart';
import '../datasources/audio_playback_datasource.dart';
import '../datasources/tcp_socket_datasource.dart';

class AudioStreamRepositoryImpl implements AudioStreamRepository {
  final TcpSocketDataSource _tcpSocketDataSource;
  final AudioCaptureDataSource _audioCaptureDataSource;
  final AudioPlaybackDataSource _audioPlaybackDataSource;

  StreamSubscription<Uint8List>? _audioCaptureSubscription;
  StreamSubscription<Uint8List>? _incomingAudioSubscription;

  final _connectionStatusController = StreamController<AudioDeviceStatus>.broadcast();

  AudioStreamRepositoryImpl({
    required TcpSocketDataSource tcpSocketDataSource,
    required AudioCaptureDataSource audioCaptureDataSource,
    required AudioPlaybackDataSource audioPlaybackDataSource,
  })  : _tcpSocketDataSource = tcpSocketDataSource,
        _audioCaptureDataSource = audioCaptureDataSource,
        _audioPlaybackDataSource = audioPlaybackDataSource {
    _tcpSocketDataSource.connectionStatusStream.listen((isConnected) {
      _connectionStatusController.add(
        isConnected ? AudioDeviceStatus.online : AudioDeviceStatus.offline
      );
    });
  }

  @override
  Stream<AudioDeviceStatus> get connectionStatusStream => _connectionStatusController.stream;

  @override
  Stream<List<String>> get deviceListStream => _tcpSocketDataSource.deviceListStream;

  @override
  Future<void> connectToDevice(AudioDevice device, {required int port}) async {
    // Exposes the TCP generic link seamlessly mapping device metadata correctly
    await _tcpSocketDataSource.connectAsClient(device.ip, port);
    
    // Automatically prepare playback hardware if the connection starts succeeding globally
    await _setupIncomingAudio();
  }

  @override
  Future<void> startReceiver({required int port}) async {
    await _tcpSocketDataSource.startServer(port);
    await _setupIncomingAudio();
  }

  Future<void> _setupIncomingAudio() async {
    await _audioPlaybackDataSource.initialize();
    _incomingAudioSubscription?.cancel();
    
    // Wire TCP directly into the speaker renderer linearly bypassing the block UI layer
    _incomingAudioSubscription = _tcpSocketDataSource.incomingAudioStream.listen((chunk) {
      _audioPlaybackDataSource.playChunk(chunk);
    });
  }

  @override
  Future<void> startStreaming({String toId = 'all'}) async {
    await _audioCaptureDataSource.startCapture();
    
    _audioCaptureSubscription?.cancel();
    
    // Wire Mic recording raw output back directly out over the hardware socket TCP bridge
    _audioCaptureSubscription = _audioCaptureDataSource.audioStream.listen((chunk) {
      _tcpSocketDataSource.sendAudioChunk(chunk, toId: toId);
    });
  }

  @override
  Future<void> stopStreaming() async {
    await _audioCaptureSubscription?.cancel();
    await _audioCaptureDataSource.stopCapture();
  }

  @override
  Future<void> disconnect() async {
    await stopStreaming();
    await _incomingAudioSubscription?.cancel();
    await _audioPlaybackDataSource.stop();
    await _tcpSocketDataSource.disconnect();
  }

  @override
  Future<void> stopReceiver() async {
    await disconnect();
    await _tcpSocketDataSource.closeServer();
  }
}
