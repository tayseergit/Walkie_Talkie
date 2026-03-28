import 'package:comunicate/features/network/domain/models/network_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/network_cubit.dart';

class DeviceTile extends StatelessWidget {
  final NetworkDevice device;

  const DeviceTile({Key? key, required this.device}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.devices),
        title: Text(device.ip),
        subtitle: Text(
          device.status == DeviceStatus.testing
              ? 'Testing connection...'
              : (device.status == DeviceStatus.online ? 'Online' : 'Offline'),
          style: TextStyle(
            color: device.status == DeviceStatus.online
                ? Colors.green
                : (device.status == DeviceStatus.offline ? Colors.red : Colors.orange),
          ),
        ),
        trailing: device.status == DeviceStatus.testing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                device.status == DeviceStatus.online ? Icons.check_circle : Icons.error,
                color: device.status == DeviceStatus.online ? Colors.green : Colors.red,
              ),
        onTap: () {
          // Tap an item to re-test the connection dynamically
          if (device.status != DeviceStatus.testing) {
            context.read<NetworkCubit>().addAndTestDevice(device.ip);
          }
        },
      ),
    );
  }
}
