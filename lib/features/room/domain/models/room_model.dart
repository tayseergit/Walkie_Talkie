import 'package:equatable/equatable.dart';
import 'peer_info.dart';

sealed class RoomState extends Equatable {
  const RoomState();
}

/// Initial screen – choose Host or Join.
class RoomIdle extends RoomState {
  const RoomIdle();
  @override
  List<Object?> get props => [];
}

/// Host is running the WS server and waiting for a client to scan the QR.
class RoomHosting extends RoomState {
  /// The full WS URL encoded in the QR code (e.g. `ws://192.168.1.5:8765`).
  final String wsUrl;
  final String myIp;
  final String myName;

  /// Connected clients in the room (excluding host device).
  final List<PeerInfo> clients;

  const RoomHosting({
    required this.wsUrl,
    required this.myIp,
    required this.myName,
    this.clients = const [],
  });

  RoomHosting copyWith({List<PeerInfo>? clients}) => RoomHosting(
    wsUrl: wsUrl,
    myIp: myIp,
    myName: myName,
    clients: clients ?? this.clients,
  );

  @override
  List<Object?> get props => [wsUrl, myIp, myName, clients];
}

/// Client is showing the QR scanner.
class RoomScanning extends RoomState {
  final String myName;
  const RoomScanning({required this.myName});
  @override
  List<Object?> get props => [myName];
}

/// WebRTC handshake is in progress (SDP/ICE exchange underway).
class RoomConnecting extends RoomState {
  final bool isHost;
  final String peerName;
  const RoomConnecting({required this.isHost, required this.peerName});
  @override
  List<Object?> get props => [isHost, peerName];
}

/// P2P link is established – call is active.
class RoomActive extends RoomState {
  final bool isHost;
  final String myId;
  final PeerInfo? selectedPeer;

  /// This device is currently holding PTT and talking.
  final bool isTalking;

  /// The remote peer is currently talking – this device's PTT is locked.
  final bool peerTalking;
  final bool isConnected;
  final List<String> connectedPeerIds;

  /// WebSocket URL for hosting (only available for hosts)
  final String? wsUrl;

  /// List of connected clients available for selecting a call target.
  final List<PeerInfo> clients;

  const RoomActive({
    required this.isHost,
    required this.myId,
    this.selectedPeer,
    this.isTalking = false,
    this.peerTalking = false,
    this.isConnected = false,
    this.connectedPeerIds = const [],
    this.wsUrl,
    this.clients = const [],
  });

  RoomActive copyWith({
    PeerInfo? selectedPeer,
    bool updateSelectedPeer = false,
    bool? isTalking,
    bool? peerTalking,
    bool? isConnected,
    List<String>? connectedPeerIds,
    String? wsUrl,
    List<PeerInfo>? clients,
  }) => RoomActive(
    isHost: isHost,
    myId: myId,
    selectedPeer: updateSelectedPeer ? selectedPeer : this.selectedPeer,
    isTalking: isTalking ?? this.isTalking,
    peerTalking: peerTalking ?? this.peerTalking,
    isConnected: isConnected ?? this.isConnected,
    connectedPeerIds: connectedPeerIds ?? this.connectedPeerIds,
    wsUrl: wsUrl ?? this.wsUrl,
    clients: clients ?? this.clients,
  );

  @override
  List<Object?> get props => [
    isHost,
    myId,
    selectedPeer,
    isTalking,
    peerTalking,
    isConnected,
    connectedPeerIds,
    wsUrl,
    clients,
  ];
}

/// The remote side closed / dropped the session.
class RoomClosed extends RoomState {
  final String reason;
  const RoomClosed(this.reason);
  @override
  List<Object?> get props => [reason];
}

/// Unrecoverable error.
class RoomError extends RoomState {
  final String message;
  const RoomError(this.message);
  @override
  List<Object?> get props => [message];
}
