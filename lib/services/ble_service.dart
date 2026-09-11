import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'gus_protocol.dart';

class BleService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(
      withNames: const ['TRCK'],
      withServices: [Guid(GusProtocol.serviceUuid)],
      timeout: const Duration(seconds: 15),
      webOptionalServices: [Guid(GusProtocol.serviceUuid)],
    );
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) => device.connect(mtu: null);
  Future<void> disconnect(BluetoothDevice device) => device.disconnect();

  Future<List<BluetoothService>> discover(BluetoothDevice device) =>
      device.discoverServices();

  BluetoothCharacteristic? findCharacteristic(
    List<BluetoothService> services,
    String uuid,
  ) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() ==
            uuid.toLowerCase()) {
          return characteristic;
        }
      }
    }
    return null;
  }

  Future<void> subscribe(
    BluetoothCharacteristic characteristic,
    void Function(List<int>) onValue,
  ) async {
    await _notifySubscription?.cancel();
    _notifySubscription = characteristic.onValueReceived.listen(onValue);
    await characteristic.setNotifyValue(true);
  }

  Future<void> write(BluetoothCharacteristic characteristic, List<int> frame) =>
      characteristic.write(
        frame,
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );

  Future<int?> requestMtu(BluetoothDevice device) async {
    try {
      return await device.requestMtu(247, predelay: 0);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _scanSubscription?.cancel();
    await _notifySubscription?.cancel();
  }
}
