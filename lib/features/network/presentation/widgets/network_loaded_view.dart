import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/network_cubit.dart';
import '../cubit/network_state.dart';
import 'add_device_form.dart';
import 'device_tile.dart';

class NetworkLoadedView extends StatelessWidget {
  final NetworkLoaded state;

  const NetworkLoadedView({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<NetworkCubit>().refreshNetworkInfo(),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.wifi, color: Colors.green),
              title: const Text('Connection Status'),
              subtitle: Text(state.connectionStatus),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.computer, color: Colors.blue),
              title: const Text('Device Local IP'),
              subtitle: Text(state.ipAddress),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Add LAN Device',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const AddDeviceForm(),
          
          const SizedBox(height: 24),
          const Text(
            'Saved Devices',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          if (state.devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No devices added yet.\nEnter an IP above to connect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              ),
            )
          else
            ...state.devices.map((device) => DeviceTile(device: device)),
        ],
      ),
    );
  }
}
