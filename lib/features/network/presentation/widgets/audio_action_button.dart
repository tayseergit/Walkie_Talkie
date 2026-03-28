import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_cubit.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_state.dart';

class AudioActionButton extends StatelessWidget {
  const AudioActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioStreamCubit, AudioStreamState>(
      builder: (context, state) {
        // Evaluate states linearly to abstract logic and represent purely via UI
        final isConnecting = state.status == StreamStatus.connecting;
        final isRecording = state.status == StreamStatus.streaming;
        final isConnected = state.status == StreamStatus.connected;
        
        Widget iconWidget;
        Color backgroundColor;

        if (isConnecting) {
          // Sending / Connecting (Loading indicator)
          iconWidget = const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          );
          backgroundColor = Colors.grey;
        } else if (isRecording) {
          // Recording => Show stop trigger
          iconWidget = const Icon(Icons.stop, color: Colors.white, size: 36);
          backgroundColor = Colors.red;
        } else if (isConnected) {
          // Default/Ready => Show Mic trigger
          iconWidget = const Icon(Icons.mic, color: Colors.white, size: 36);
          backgroundColor = Colors.green;
        } else {
          // Disconnected => Disabled state
          iconWidget = const Icon(Icons.mic_off, color: Colors.white, size: 36);
          backgroundColor = Colors.grey.shade400;
        }

        return GestureDetector(
          onTap: () {
            // Drop input while safely negotiating streams
            if (isConnecting) return;
            
            if (!isConnected && !isRecording) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please connect or host a session before streaming.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            
            final cubit = context.read<AudioStreamCubit>();
            if (isRecording) {
              // Trigger stop recording natively
              cubit.stopMicrophoneStream();
            } else {
              // Trigger capture and stream logically
              cubit.startMicrophoneStream();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 6)
                ),
              ]
            ),
            child: Center(child: iconWidget),
          ),
        );
      },
    );
  }
}
