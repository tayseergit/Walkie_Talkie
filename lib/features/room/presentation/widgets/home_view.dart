import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/room_cubit.dart';
import 'shared_widgets.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.radio_sharp,
                      size: 72,
                      color: Color(0xFF58A6FF),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'walkie-talkie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                     
                    const SizedBox(height: 40),
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Your name (optional)',
                        hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF8B949E),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF30363D)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    BigButton(
                      label: 'Host Room',
                      icon: Icons.qr_code_2,
                      color: const Color(0xFF238636),
                      onPressed: () =>
                          context.read<RoomCubit>().hostRoom(_nameCtrl.text.trim()),
                    ),
                    const SizedBox(height: 14),
                    BigButton(
                      label: 'Join Room',
                      icon: Icons.qr_code_scanner,
                      color: const Color(0xFF1F6FEB),
                      onPressed: () => context.read<RoomCubit>().startJoining(
                        _nameCtrl.text.trim(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
