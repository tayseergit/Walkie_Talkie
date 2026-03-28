import 'package:equatable/equatable.dart';
import '../../domain/models/network_device.dart';

abstract class NetworkState extends Equatable {
  const NetworkState();

  @override
  List<Object?> get props => [];
}

class NetworkInitial extends NetworkState {}

class NetworkLoading extends NetworkState {}

class NetworkLoaded extends NetworkState {
  final String ipAddress;
  final String connectionStatus;
  final List<NetworkDevice> devices;

  const NetworkLoaded({
    required this.ipAddress,
    required this.connectionStatus,
    this.devices = const [],
  });

  NetworkLoaded copyWith({
    String? ipAddress,
    String? connectionStatus,
    List<NetworkDevice>? devices,
  }) {
    return NetworkLoaded(
      ipAddress: ipAddress ?? this.ipAddress,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      devices: devices ?? this.devices,
    );
  }

  @override
  List<Object?> get props => [ipAddress, connectionStatus, devices];
}

class NetworkError extends NetworkState {
  final String message;

  const NetworkError(this.message);

  @override
  List<Object?> get props => [message];
}
