import 'dart:async';
import '../entities/audio_device.dart';

abstract class AudioStreamRepository {
  /// Connects to a dynamically passed target device for audio streaming
  Future<void> connectToDevice(AudioDevice device, {required int port});
  
  /// Formally disconnects from the current device socket
  Future<void> disconnect();

  /// Captures PCM microphone data and pushes it over the raw socket pipeline explicitly
  Future<void> startStreaming({String toId = 'all'});
  
  /// Pauses microphone broadcasting
  Future<void> stopStreaming();

  /// Starts a persistent background receiver to ingest chunks to an audio player 
  Future<void> startReceiver({required int port});

  /// Destroys receiver context
  Future<void> stopReceiver();

  /// Publishes underlying connectivity transitions cleanly
  Stream<AudioDeviceStatus> get connectionStatusStream;

  /// Exposes the live dynamic cluster of actively targeted devices within the Hub
  Stream<List<String>> get deviceListStream;
}
