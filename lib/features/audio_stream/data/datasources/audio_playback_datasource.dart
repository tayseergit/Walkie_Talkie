import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:sound_stream/sound_stream.dart';

class AudioPlaybackDataSource {
  final PlayerStream _player = PlayerStream();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _player.initialize(
        sampleRate: 44100,
       );
      await _player.start();
      _isInitialized = true;
      developer.log('Native sound_stream playback hardware initialized', name: 'AudioPlaybackDataSource');
    }
  }

  /// Pushes individual byte chunks cleanly to native speaker context seamlessly
  Future<void> playChunk(Uint8List chunk) async {
    if (_isInitialized) {
      // Linear low-latency rendering
      await _player.writeChunk(chunk);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isInitialized = false;
    developer.log('Speaker framework completely stopped', name: 'AudioPlaybackDataSource');
  }
}
