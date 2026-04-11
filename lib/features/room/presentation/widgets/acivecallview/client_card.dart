import 'package:flutter/material.dart';

import '../../../domain/models/peer_info.dart';

class ClientCard extends StatelessWidget {
  final PeerInfo client;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  const ClientCard({
    super.key,
    required this.client,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              connected ? 'Tap to disconnect' : 'Tap to connect',
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
    );
  }
}
