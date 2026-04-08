import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../cubit/room_cubit.dart';
import '../../../domain/models/room_model.dart';
import '../shared_widgets.dart';

class HostingView extends StatelessWidget {
  final RoomHosting state;

  const HostingView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final clientConnected = state.clients.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('Host Room'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.read<RoomCubit>().disconnect(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: clientConnected
                        ? StatusChip(
                            key: const ValueKey('connected'),
                            icon: Icons.check_circle,
                            label: '${state.clients.length} client(s) in room',
                            color: Colors.green,
                          )
                        : const StatusChip(
                            key: ValueKey('waiting'),
                            icon: Icons.hourglass_top,
                            label: 'Waiting for clients...',
                            color: Color(0xFF8B949E),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Card(
                    color: const Color(0xFF161B22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Scan to Join',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: QrImageView(
                              data: state.wsUrl,
                              size: constraints.maxWidth < 380 ? 140 : 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: state.wsUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('URL copied!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Text(
                              state.wsUrl,
                              style: const TextStyle(
                                color: Color(0xFF58A6FF),
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connected Clients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.clients.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final client = state.clients[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 20,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            client.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            client.ip,
                            style: const TextStyle(
                              color: Color(0xFF8B949E),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (state.clients.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Text(
                      'No clients connected yet',
                      style: TextStyle(color: Color(0xFF8B949E)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
