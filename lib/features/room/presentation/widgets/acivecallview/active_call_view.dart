import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../cubit/room_cubit.dart';
import '../../../domain/models/room_model.dart';
import 'client_card.dart';

class ActiveCallView extends StatelessWidget {
  final RoomActive state;

  const ActiveCallView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RoomCubit>();
    final connectedCount = state.connectedPeers.length;
    final isTalking = state.isTalking;
    final peerTalking = state.peerTalking;
    
    final selectedCount = state.selectedPeers.length;
    final activeConnectedCount = state.connectedPeers.intersection(state.selectedPeers).length;
    final hasActiveConnected = activeConnectedCount > 0;
    final pttLocked = !hasActiveConnected || peerTalking;

    String statusText;
    if (selectedCount == 0) {
      statusText = 'Select at least one client to start call';
    } else if (hasActiveConnected) {
      statusText = peerTalking
          ? 'Someone is talking...'
          : 'Connected to $activeConnectedCount peer(s)';
    } else {
      statusText = 'Tap a peer to connect';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: Text(state.isHost ? 'Host Room' : 'Joined Room'),
        actions: [
          TextButton.icon(
            onPressed: () => cubit.disconnect(),
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900
              ? 4
              : width >= 700
              ? 3
              : 2;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.wsUrl != null)
                  Card(
                    color: const Color(0xFF161B22),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          QrImageView(
                            data: state.wsUrl!,
                            size: 56,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: state.wsUrl!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('URL copied'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Text(
                                state.wsUrl!,
                                style: const TextStyle(
                                  color: Color(0xFF58A6FF),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Clients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Connected: $connectedCount',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.clients.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final client = state.clients[index];
                    return ClientCard(
                      client: client,
                      selected: state.selectedPeers.contains(client.name),
                      status: state.connectionStates[client.name] ?? ConnectionStatus.disconnected,
                      onTap: () => cubit.callPeer(client),
                      onToggleSelect: (_) => cubit.togglePeerSelection(client.name),
                    );
                  },
                ),
                if (state.clients.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Text(
                      'No clients in room yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8B949E)),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: hasActiveConnected
                        ? Colors.greenAccent
                        : const Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTapDown: pttLocked ? null : (_) => cubit.pressedPtt(),
                    onTapUp: (_) => cubit.releasedPtt(),
                    onLongPressStart: pttLocked
                        ? null
                        : (_) => cubit.pressedPtt(),
                    onLongPressEnd: (_) => cubit.releasedPtt(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isTalking ? 150 : 130,
                      height: isTalking ? 150 : 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pttColor(isTalking, pttLocked),
                      ),
                      child: Center(
                        child: Icon(
                          pttLocked
                              ? Icons.lock_outline
                              : (isTalking ? Icons.mic : Icons.mic_none),
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  pttLocked
                      ? 'PTT disabled until a selected peer connects'
                      : (isTalking ? 'Release to stop' : 'Hold to talk'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pttLocked ? Colors.orange : const Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _pttColor(bool talking, bool locked) {
    if (locked) return const Color(0xFF30363D);
    if (talking) return Colors.red.shade700;
    return const Color(0xFF238636);
  }
}
