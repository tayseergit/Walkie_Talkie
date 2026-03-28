import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../domain/models/network_device.dart';
import '../../data/services/tcp_service.dart';
import 'network_state.dart';

class NetworkCubit extends Cubit<NetworkState> {
  final NetworkInfo _networkInfo;
  final TcpService _tcpService;

  NetworkCubit({
    NetworkInfo? networkInfo,
    TcpService? tcpService,
  })  : _networkInfo = networkInfo ?? NetworkInfo(),
        _tcpService = tcpService ?? TcpService(),
        super(NetworkInitial()) {
    // Start the TCP server on port 5000 automatically to allow others to connect to us
    _tcpService.startServer();
  }

  @override
  Future<void> close() {
    _tcpService.stopServer();
    return super.close();
  }

  /// Fetches the local IP address and updates the state
  Future<void> fetchNetworkInfo() async {
    // Preserve previously discovered devices
    List<NetworkDevice> currentDevices = [];
    if (state is NetworkLoaded) {
      currentDevices = (state as NetworkLoaded).devices;
    }

    emit(NetworkLoading());
    try {
      final String? wifiIP = await _networkInfo.getWifiIP();

      if (wifiIP != null && wifiIP.isNotEmpty) {
        emit(
          NetworkLoaded(
            ipAddress: wifiIP,
            connectionStatus: 'Connected',
            devices: currentDevices, 
          ),
        );
      } else {
        emit(
          const NetworkError('Not connected to a network or IP unavailable.'),
        );
      }
    } catch (e) {
      emit(NetworkError('Failed to get network info: ${e.toString()}'));
    }
  }

  /// Refreshes the current network information
  Future<void> refreshNetworkInfo() async {
    await fetchNetworkInfo();
  }

  /// Tests TCP connection via the service and manages the loading/error state
  Future<void> addAndTestDevice(String ipAddress) async {
    if (state is! NetworkLoaded) return;
    
    final currentState = state as NetworkLoaded;
    
    // 1. Add device to list (or update existing) and set status to testing
    int existingIndex = currentState.devices.indexWhere((d) => d.ip == ipAddress);
    List<NetworkDevice> updatedDevices = List.from(currentState.devices);
    
    if (existingIndex >= 0) {
      updatedDevices[existingIndex] = updatedDevices[existingIndex].copyWith(status: DeviceStatus.testing);
    } else {
      updatedDevices.add(NetworkDevice(ip: ipAddress, status: DeviceStatus.testing));
    }
    
    // Emit immediate state showing device is being tested
    emit(currentState.copyWith(devices: updatedDevices));

    // 2. Perform actual TCP socket connection test and handshake
    final bool isOnline = await _tcpService.testConnection(ipAddress);

    // 3. Since state might have changed due to async delay, retrieve the latest state and update the status
    if (state is NetworkLoaded) {
      final latestState = state as NetworkLoaded;
      List<NetworkDevice> finalDevices = List.from(latestState.devices);
      
      int index = finalDevices.indexWhere((d) => d.ip == ipAddress);
      if (index >= 0) {
        finalDevices[index] = finalDevices[index].copyWith(
          status: isOnline ? DeviceStatus.online : DeviceStatus.offline
        );
      }
      
      emit(latestState.copyWith(devices: finalDevices));
    }
  }
}
