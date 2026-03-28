import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/network_cubit.dart';
import '../cubit/network_state.dart';
import '../widgets/network_loaded_view.dart';
import '../widgets/audio_action_button.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<NetworkCubit>().refreshNetworkInfo();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          BlocBuilder<NetworkCubit, NetworkState>(
            builder: (context, state) {
              if (state is NetworkInitial) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => context.read<NetworkCubit>().fetchNetworkInfo(),
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
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          state.message,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.read<NetworkCubit>().refreshNetworkInfo(),
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
    );
  }
}
