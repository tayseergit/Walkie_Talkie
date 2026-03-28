import 'package:equatable/equatable.dart';

enum DeviceStatus { online, offline, testing }

class NetworkDevice extends Equatable {
  final String ip;
  final DeviceStatus status;

  const NetworkDevice({
    required this.ip,
    required this.status,
  });

  /// Allows immutably updating parts of the model
  NetworkDevice copyWith({
    String? ip,
    DeviceStatus? status,
  }) {
    return NetworkDevice(
      ip: ip ?? this.ip,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [ip, status];
}
