import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_cubit.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_state.dart';

class AudioActionButton extends StatefulWidget {
  const AudioActionButton({super.key});

  @override
  State<AudioActionButton> createState() => _AudioActionButtonState();
}

class _AudioActionButtonState extends State<AudioActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AudioStreamCubit, AudioStreamState>(
      listenWhen: (previous, current) {
        return previous.status != current.status;
      },
      listener: (context, state) {
        if (state.status == StreamStatus.recording) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.reset();
        }
      },
      builder: (context, state) {
        final isConnecting = state.status == StreamStatus.connecting;
        final isRecording = state.status == StreamStatus.recording;
        final isSending = state.status == StreamStatus.sending;
        final isConnected = state.status == StreamStatus.connected;
        
        Widget iconWidget;
        Color backgroundColor;

        if (isConnecting || isSending) {
          iconWidget = const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          );
          backgroundColor = isSending ? Colors.red.shade300 : Colors.grey;
        } else if (isRecording) {
          iconWidget = const Icon(Icons.stop, color: Colors.white, size: 36);
          backgroundColor = Colors.red;
        } else if (isConnected) {
          iconWidget = const Icon(Icons.mic, color: Colors.white, size: 36);
          backgroundColor = Colors.green;
        } else {
          iconWidget = const Icon(Icons.mic_off, color: Colors.white, size: 36);
          backgroundColor = Colors.grey.shade400;
        }

        return GestureDetector(
          onTap: () {
            if (isConnecting || isSending) return;
            
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
              cubit.stopMicrophoneStream();
            } else {
              cubit.startMicrophoneStream();
            }
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isRecording ? _pulseAnimation.value : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: backgroundColor.withOpacity(isRecording ? 0.8 : 0.5),
                        blurRadius: isRecording ? 25 * _pulseAnimation.value : 15,
                        spreadRadius: isRecording ? 5 * _pulseAnimation.value : 0,
                        offset: const Offset(0, 6)
                      ),
                    ]
                  ),
                  child: Center(child: iconWidget),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
