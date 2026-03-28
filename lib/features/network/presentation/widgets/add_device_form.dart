import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/network_cubit.dart';

class AddDeviceForm extends StatefulWidget {
  const AddDeviceForm({Key? key}) : super(key: key);

  @override
  State<AddDeviceForm> createState() => _AddDeviceFormState();
}

class _AddDeviceFormState extends State<AddDeviceForm> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'IP Address',
              hintText: 'e.g., 192.168.1.5',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            final ip = _ipController.text.trim();
            if (ip.isNotEmpty) {
              context.read<NetworkCubit>().addAndTestDevice(ip);
              _ipController.clear();
              FocusScope.of(context).unfocus(); // Drops the keyboard
            }
          },
          icon: const Icon(Icons.add_link),
          label: const Text('Test'),
        ),
      ],
    );
  }
}
