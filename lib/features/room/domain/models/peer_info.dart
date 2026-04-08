import 'package:equatable/equatable.dart';

/// Represents the remote peer in a 1-to-1 session.
class PeerInfo extends Equatable {
  final String name;
  final String ip;

  const PeerInfo({required this.name, required this.ip});

  @override
  List<Object?> get props => [name, ip];
}
