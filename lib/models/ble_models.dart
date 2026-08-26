import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleLogEntry {
  final DateTime time;
  final String direction;
  final String message;
  final bool isError;

  const BleLogEntry({
    required this.time,
    required this.direction,
    required this.message,
    this.isError = false,
  });
}

class TemperatureSample {
  final DateTime time;
  final double? celsius;
  final bool valid;

  const TemperatureSample({
    required this.time,
    required this.celsius,
    required this.valid,
  });
}

class DeviceSnapshot {
  final BluetoothDevice device;
  final int? rssi;
  final String name;
  final String id;

  DeviceSnapshot({required this.device, this.rssi})
    : name = device.platformName.isEmpty ? '未命名设备' : device.platformName,
      id = device.remoteId.toString();
}
