import 'package:equatable/equatable.dart';
import '../../domain/entities/audio_device.dart';

enum StreamStatus { disconnected, connecting, connected, streaming, error }

class AudioStreamState extends Equatable {
  final StreamStatus status;
  final AudioDevice? targetDevice;
  final String? errorMessage;
  final bool isReceiverMode;

  const AudioStreamState({
    this.status = StreamStatus.disconnected,
    this.targetDevice,
    this.errorMessage,
    this.isReceiverMode = false,
  });

  AudioStreamState copyWith({
    StreamStatus? status,
    AudioDevice? targetDevice,
    String? errorMessage,
    bool? isReceiverMode,
  }) {
    return AudioStreamState(
      status: status ?? this.status,
      targetDevice: targetDevice ?? this.targetDevice,
      errorMessage: errorMessage ?? this.errorMessage,
      isReceiverMode: isReceiverMode ?? this.isReceiverMode,
    );
  }

  @override
  List<Object?> get props => [status, targetDevice, errorMessage, isReceiverMode];
}
