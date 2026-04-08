import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/room_cubit.dart';
import '../../domain/models/room_model.dart';
import '../widgets/acivecallview/active_call_view.dart';
import '../widgets/connecting_view.dart';
import '../widgets/home_view.dart';
import '../widgets/host/hosting_view.dart';
import '../widgets/scan_view.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoomCubit, RoomState>(
      listener: (context, state) {
        if (state is RoomClosed || state is RoomError) {
          final msg = state is RoomClosed
              ? state.reason
              : (state as RoomError).message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: state is RoomError
                  ? Colors.red.shade700
                  : Colors.orange,
            ),
          );
        }
      },
      builder: (context, state) {
        return switch (state) {
          RoomIdle() => const HomeView(),
          RoomHosting() => HostingView(state: state),
          RoomScanning() => ScanView(myName: state.myName),
          RoomConnecting() => ConnectingView(state: state),
          RoomActive() => ActiveCallView(state: state),
          RoomClosed() => const HomeView(),
          RoomError() => const HomeView(),
        };
      },
    );
  }
}
