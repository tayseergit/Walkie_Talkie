import 'package:flutter/material.dart';

import '../../domain/models/room_model.dart';

class ConnectingView extends StatelessWidget {
  final RoomConnecting state;

  const ConnectingView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF58A6FF)),
                const SizedBox(height: 24),
                Text(
                  'Connecting to ${state.peerName}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Setting up secure audio channel',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
