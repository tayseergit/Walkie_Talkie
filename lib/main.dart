import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/network/presentation/cubit/network_cubit.dart';
import 'features/network/presentation/screens/network_screen.dart';

// Audio Stream feature dependencies
import 'features/audio_stream/data/datasources/audio_capture_datasource.dart';
import 'features/audio_stream/data/datasources/audio_playback_datasource.dart';
import 'features/audio_stream/data/datasources/tcp_socket_datasource.dart';
import 'features/audio_stream/data/repositories/audio_stream_repository_impl.dart';
import 'features/audio_stream/presentation/cubit/audio_stream_cubit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Communicate App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Wrap the starting screen with MultiBlocProvider to provide both Network and Audio streams globally
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => NetworkCubit()),
          BlocProvider(
            create: (context) => AudioStreamCubit(
              repository: AudioStreamRepositoryImpl(
                tcpSocketDataSource: TcpSocketDataSource(),
                audioCaptureDataSource: AudioCaptureDataSource(),
                audioPlaybackDataSource: AudioPlaybackDataSource(),
              ),
            ),
          ),
        ],
        child: const NetworkScreen(),
      ),
    );
  }
}
