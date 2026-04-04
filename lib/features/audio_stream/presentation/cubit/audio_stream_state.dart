import 'package:equatable/equatable.dart';
import '../../domain/entities/audio_device.dart';

enum StreamStatus { disconnected, connecting, connected, recording, sending, error }

class AudioStreamState extends Equatable {
  final StreamStatus status;
  final AudioDevice? targetDevice;
  final String? errorMessage;
  final bool isReceiverMode;
  final List<String> connectedDevices;
  final List<String> selectedTargetIds;

  const AudioStreamState({
    this.status = StreamStatus.disconnected,
    this.targetDevice,
    this.errorMessage,
    this.isReceiverMode = false,
    this.connectedDevices = const [],
    this.selectedTargetIds = const [],
  });

  AudioStreamState copyWith({
    StreamStatus? status,
    AudioDevice? targetDevice,
    String? errorMessage,
    bool? isReceiverMode,
    List<String>? connectedDevices,
    List<String>? selectedTargetIds,
  }) {
    return AudioStreamState(
      status: status ?? this.status,
      targetDevice: targetDevice ?? this.targetDevice,
      errorMessage: errorMessage ?? this.errorMessage,
      isReceiverMode: isReceiverMode ?? this.isReceiverMode,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      selectedTargetIds: selectedTargetIds ?? this.selectedTargetIds,
    );
  }

  @override
  List<Object?> get props => [status, targetDevice, errorMessage, isReceiverMode, connectedDevices, selectedTargetIds];
}
