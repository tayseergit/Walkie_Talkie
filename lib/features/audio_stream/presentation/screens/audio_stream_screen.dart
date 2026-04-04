import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/audio_device.dart';
import '../cubit/audio_stream_cubit.dart';
import '../cubit/audio_stream_state.dart';

class AudioStreamScreen extends StatelessWidget {
  const AudioStreamScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Audio Stream')),
      body: BlocConsumer<AudioStreamCubit, AudioStreamState>(
        listener: (context, state) {
          if (state.status == StreamStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? 'System Error'), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusSection(state),
                const SizedBox(height: 32),
                _buildModeSelection(context, state),
                const SizedBox(height: 32),
                _buildStreamingControls(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(AudioStreamState state) {
    Color statusColor = Colors.grey;
    String statusText = 'Disconnected';

    switch (state.status) {
      case StreamStatus.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting / Listening...';
        break;
      case StreamStatus.connected:
        statusColor = Colors.green;
        statusText = 'Connection Established';
        break;
      case StreamStatus.recording:
        statusColor = Colors.redAccent;
        statusText = 'Live Broadcasting (Mic ON)';
        break;
      case StreamStatus.sending:
        statusColor = Colors.orange;
        statusText = 'Dispatching Output...';
        break;
      case StreamStatus.error:
        statusColor = Colors.red;
        statusText = 'System Fault';
        break;
      default:
        break;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            const Text('Network Link Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(statusText, style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (state.targetDevice != null) ...[
              const SizedBox(height: 12),
              Text('Paired: ${state.targetDevice!.ip}', style: const TextStyle(color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelection(BuildContext context, AudioStreamState state) {
    if (state.status == StreamStatus.connected || state.status == StreamStatus.recording || state.status == StreamStatus.sending) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.stop_screen_share),
        label: const Text('Kill Connection'),
        onPressed: () => context.read<AudioStreamCubit>().disconnect(),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
      );
    }
    
    if (state.status == StreamStatus.connecting) {
      return const Center(child: CircularProgressIndicator());
    }

    final ipController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.headphones),
          label: const Text('Host Session (Listen for Audio)'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          onPressed: () => context.read<AudioStreamCubit>().startServerMode(),
        ),
        const SizedBox(height: 32),
        const Text(
          'Dynamic Join (Requires IP currently, discovery coming soon)',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Target Device IP',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24)),
              child: const Text('Join'),
              onPressed: () {
                final ip = ipController.text.trim();
                if (ip.isNotEmpty) {
                  // Pass dynamic device abstraction safely
                  final device = AudioDevice(
                    id: DateTime.now().millisecondsSinceEpoch.toString(), 
                    name: 'Target Device', 
                    ip: ip, 
                    status: AudioDeviceStatus.online
                  );
                  context.read<AudioStreamCubit>().connectToDevice(device);
                }
              },
            )
          ],
        )
      ],
    );
  }

  Widget _buildStreamingControls(BuildContext context, AudioStreamState state) {
    if (state.status != StreamStatus.connected && state.status != StreamStatus.recording && state.status != StreamStatus.sending) {
      return const SizedBox.shrink();
    }
    
    if (state.isReceiverMode) {
      return const Card(
        color: Colors.black87,
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.speaker, color: Colors.greenAccent, size: 64),
              SizedBox(height: 16),
              Text('Receiving Audio...', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final isStreaming = state.status == StreamStatus.recording;
    
    return Column(
      children: [
        const Text('Tap mic to toggle live broadcast', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () {
            if (isStreaming) {
              context.read<AudioStreamCubit>().stopMicrophoneStream();
            } else {
              context.read<AudioStreamCubit>().startMicrophoneStream();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: isStreaming ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: isStreaming ? Colors.red : Colors.green, width: 4),
              boxShadow: isStreaming 
                ? [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)] 
                : [],
            ),
            child: Icon(
              isStreaming ? Icons.mic_off : Icons.mic,
              size: 64,
              color: isStreaming ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}
