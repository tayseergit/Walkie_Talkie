import 'package:equatable/equatable.dart';

enum AudioDeviceStatus { online, offline, streaming, receiving }

class AudioDevice extends Equatable {
  final String id;
  final String name;
  final String ip;
  final AudioDeviceStatus status;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.status,
  });

  /// Allows immutably updating parts of the model (future-ready for dynamic lists)
  AudioDevice copyWith({
    String? id,
    String? name,
    String? ip,
    AudioDeviceStatus? status,
  }) {
    return AudioDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, name, ip, status];
}
