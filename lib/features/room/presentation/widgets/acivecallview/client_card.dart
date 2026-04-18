import 'package:flutter/material.dart';

import '../../../domain/models/peer_info.dart';
import '../../../domain/models/room_model.dart';

class ClientCard extends StatelessWidget {
  final PeerInfo client;
  final bool selected;
  final ConnectionStatus status;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleSelect;

  const ClientCard({
    super.key,
    required this.client,
    required this.selected,
    required this.status,
    required this.onTap,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = status == ConnectionStatus.connected;
    final connecting = status == ConnectionStatus.connecting;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF58A6FF)
                : (connected ? Colors.green : const Color(0xFF30363D)),
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: selected,
                  onChanged: onToggleSelect,
                  activeColor: const Color(0xFF58A6FF),
                  checkColor: Colors.black,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (connecting)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
                      ),
                    )
                  else
                    Icon(
                      Icons.person_outline,
                      color: selected
                          ? const Color(0xFF58A6FF)
                          : (connected ? Colors.green : const Color(0xFF8B949E)),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client.ip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    connecting
                        ? 'Connecting...'
                        : (connected ? 'Tap to disconnect' : 'Tap to connect'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: connected ? Colors.redAccent : const Color(0xFF58A6FF),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
