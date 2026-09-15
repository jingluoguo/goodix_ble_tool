import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'measure_kind.dart';

export 'measure_kind.dart';

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

/// 一次测量链的最终结果。注意 status=0x01 也可能全是 0（超时结束）。
class MeasureOutcome {
  final MeasureKind kind;
  final DateTime time;
  final int? hr;
  final int? hrv;
  final int? spo2;
  final bool valid;

  const MeasureOutcome({
    required this.kind,
    required this.time,
    this.hr,
    this.hrv,
    this.spo2,
    required this.valid,
  });

  String get summary {
    final parts = <String>[];
    if (hr != null && hr! > 0) parts.add('心率 $hr bpm');
    if (hrv != null && hrv! > 0) parts.add('HRV $hrv ms');
    if (spo2 != null && spo2! > 0) parts.add('血氧 $spo2 %');
    if (parts.isEmpty) return '无有效数据（超时结束或信号不足）';
    return parts.join(' · ');
  }
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
