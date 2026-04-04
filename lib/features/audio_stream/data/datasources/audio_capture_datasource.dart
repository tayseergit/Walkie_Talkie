import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:record/record.dart';

class AudioCaptureDataSource {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;
  final _audioStreamController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  Future<void> startCapture() async {
    if (await _audioRecorder.hasPermission()) {
      try {
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1, // Strict Mono to match simple stream architecture
        ));

        _micSubscription = stream.listen((data) {
          _audioStreamController.add(data);
        });
        developer.log('Microphone capture stream hardware started', name: 'AudioCaptureDataSource');
      } catch (e) {
        developer.log('Audio capture failed: $e', name: 'AudioCaptureDataSource');
        throw Exception('Audio capture failed: $e');
      }
    } else {
      throw Exception('Microphone permission denied globally');
    }
  }

  Future<void> stopCapture() async {
    await _micSubscription?.cancel();
    await _audioRecorder.stop();
    developer.log('Microphone hardware explicitly released', name: 'AudioCaptureDataSource');
  }
}
