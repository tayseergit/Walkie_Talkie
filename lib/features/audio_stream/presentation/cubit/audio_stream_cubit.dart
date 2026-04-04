import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/audio_device.dart';
import '../../domain/repositories/audio_stream_repository.dart';
import 'audio_stream_state.dart';

class AudioStreamCubit extends Cubit<AudioStreamState> {
  final AudioStreamRepository _repository;
  StreamSubscription<AudioDeviceStatus>? _connectionSubscription;
  StreamSubscription<List<String>>? _deviceListSubscription;
  final int _audioPort = 6000; // Distinct networking route specifically structured for Audio TCP pipeline

  AudioStreamCubit({
    required AudioStreamRepository repository,
  })  : _repository = repository,
        super(const AudioStreamState()) {
    _monitorConnection();
  }

  void _monitorConnection() {
    _connectionSubscription = _repository.connectionStatusStream.listen((status) {
      if (status == AudioDeviceStatus.offline) {
        emit(state.copyWith(
          status: StreamStatus.disconnected,
          errorMessage: 'Connection lost or terminated globally.',
          connectedDevices: [],
          selectedTargetIds: [],
        ));
      } else if (status == AudioDeviceStatus.online) {
        emit(state.copyWith(status: StreamStatus.connected, errorMessage: null));
      }
    });

    _deviceListSubscription = _repository.deviceListStream.listen((devices) {
      // Safely purge outdated targets from selection explicitly when connections sever gracefully 
      final cleanSelection = state.selectedTargetIds.where((id) => devices.contains(id)).toList();
      emit(state.copyWith(connectedDevices: devices, selectedTargetIds: cleanSelection));
    });
  }

  void toggleTargetId(String id) {
    final currentList = List<String>.from(state.selectedTargetIds);
    if (currentList.contains(id)) {
      currentList.remove(id);
    } else {
      currentList.add(id);
    }
    emit(state.copyWith(selectedTargetIds: currentList));
  }

  /// Start server so this device can receive incoming audio data efficiently
  Future<void> startServerMode() async {
    try {
      emit(state.copyWith(status: StreamStatus.connecting, isReceiverMode: true));
      await _repository.startReceiver(port: _audioPort);
    } catch (e) {
      emit(state.copyWith(status: StreamStatus.error, errorMessage: e.toString()));
    }
  }

  /// Future Ready: Resolves the connection utilizing the generalized object allowing device-manager passing
  Future<void> connectToDevice(AudioDevice device) async {
    try {
      emit(state.copyWith(
        status: StreamStatus.connecting,
        targetDevice: device,
        isReceiverMode: false,
      ));
      
      await _repository.connectToDevice(device, port: _audioPort);
    } catch (e) {
      emit(state.copyWith(
        status: StreamStatus.error,
        errorMessage: 'Failed to negotiate stream line natively: ${e.toString()}',
      ));
    }
  }

  /// Ignites microphone broadcasts over active socket
  Future<void> startMicrophoneStream() async {
    if (state.status != StreamStatus.connected) return;
    
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      emit(state.copyWith(status: StreamStatus.error, errorMessage: 'Microphone permission denied.'));
      return;
    }

    try {
      final targetRouting = state.selectedTargetIds.isEmpty ? 'all' : state.selectedTargetIds.join(',');
      await _repository.startStreaming(toId: targetRouting);
      emit(state.copyWith(status: StreamStatus.recording));
    } catch (e) {
      emit(state.copyWith(status: StreamStatus.error, errorMessage: 'Mic injection failed: $e'));
    }
  }

  /// Severs microphone broadcast safely maintaining the TCP architecture
  Future<void> stopMicrophoneStream() async {
    if (state.status != StreamStatus.recording) return;
    
    try {
      emit(state.copyWith(status: StreamStatus.sending));
      await _repository.stopStreaming();
      await Future.delayed(const Duration(milliseconds: 600)); // Show sending feedback briefly
      emit(state.copyWith(status: StreamStatus.connected)); // Falls back seamlessly cleanly
    } catch (e) {
      emit(state.copyWith(status: StreamStatus.error, errorMessage: 'Stop disruption error: $e'));
    }
  }

  /// Detaches whole systems safely via domain requirements globally
  Future<void> disconnect() async {
    await _repository.disconnect();
    if (state.isReceiverMode) {
      await _repository.stopReceiver();
    }
    emit(state.copyWith(status: StreamStatus.disconnected, targetDevice: null));
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    _deviceListSubscription?.cancel();
    _repository.stopReceiver();
    return super.close();
  }
}
