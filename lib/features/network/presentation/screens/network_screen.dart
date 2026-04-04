import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/network_cubit.dart';
import '../cubit/network_state.dart';
import '../widgets/network_loaded_view.dart';
import '../widgets/audio_action_button.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_cubit.dart';
import '../../../audio_stream/presentation/cubit/audio_stream_state.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Info'),
        actions: [
          BlocBuilder<AudioStreamCubit, AudioStreamState>(
            builder: (context, audioState) {
              final isConnecting = audioState.status == StreamStatus.connecting;
              final isConnected =
                  audioState.status == StreamStatus.connected ||
                  audioState.status == StreamStatus.recording ||
                  audioState.status == StreamStatus.sending;

              if (isConnecting) {
                if (audioState.isReceiverMode) {
                  return TextButton.icon(
                    onPressed: () =>
                        context.read<AudioStreamCubit>().disconnect(),
                    icon: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange,
                      ),
                    ),
                    label: const Text(
                      'Hosting (Cancel)',
                      style: TextStyle(color: Colors.orange),
                    ),
                  );
                }
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (isConnected) {
                return TextButton.icon(
                  onPressed: () =>
                      context.read<AudioStreamCubit>().disconnect(),
                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              return TextButton.icon(
                onPressed: () =>
                    context.read<AudioStreamCubit>().startServerMode(),
                icon: const Icon(Icons.podcasts),
                label: const Text('Host Session'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<NetworkCubit>().refreshNetworkInfo();
            },
          ),
        ],
      ),
      body: BlocListener<AudioStreamCubit, AudioStreamState>(
        listenWhen: (previous, current) {
          if (previous.status == StreamStatus.sending && current.status == StreamStatus.connected) {
            return false;
          }
          return previous.status != current.status;
        },
        listener: (context, state) {
          if (state.status == StreamStatus.error &&
              state.errorMessage != null) {
            print(state.errorMessage);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state.status == StreamStatus.connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: BlocBuilder<NetworkCubit, NetworkState>(
                    builder: (context, state) {
                      if (state is NetworkInitial) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () =>
                                context.read<NetworkCubit>().fetchNetworkInfo(),
                            child: const Text('Get Network Info'),
                          ),
                        );
                      } else if (state is NetworkLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is NetworkLoaded) {
                        return NetworkLoadedView(state: state);
                      } else if (state is NetworkError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () => context
                                      .read<NetworkCubit>()
                                      .refreshNetworkInfo(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                BlocBuilder<AudioStreamCubit, AudioStreamState>(
                  builder: (context, state) {
                    if (state.connectedDevices.isEmpty) return const SizedBox.shrink();
                    return Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.05),
                          border: Border(top: BorderSide(color: Colors.grey.shade300))
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Active Hub Targets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                TextButton.icon(
                                  icon: const Icon(Icons.select_all, size: 18),
                                  label: const Text('Select All'),
                                  onPressed: () {
                                    final cubit = context.read<AudioStreamCubit>();
                                    // Hacky Select All: loop and toggle if missing 
                                    for (var ip in state.connectedDevices) {
                                      if (!state.selectedTargetIds.contains(ip)) {
                                        cubit.toggleTargetId(ip);
                                      }
                                    }
                                  },
                                )
                              ],
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: state.connectedDevices.length,
                                itemBuilder: (context, i) {
                                  final ip = state.connectedDevices[i];
                                  final isSelected = state.selectedTargetIds.contains(ip);
                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: CheckboxListTile(
                                      title: Text(ip, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      secondary: const Icon(Icons.speaker_phone, color: Colors.blue),
                                      value: isSelected,
                                      onChanged: (val) {
                                        context.read<AudioStreamCubit>().toggleTargetId(ip);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 90), // Spacing for floating action button
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Reusable Audio Action Button floated natively over existing UI
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: AudioActionButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
