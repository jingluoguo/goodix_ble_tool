import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ble_models.dart';
import '../services/ble_service.dart';
import '../services/gus_protocol.dart';
import '../services/history_export_service.dart';

class BleController extends GetxController {
  final BleService _ble = BleService();
  final adapterState = BluetoothAdapterState.unknown.obs;
  final scanning = false.obs;
  final scanDevices = <String, DeviceSnapshot>{}.obs;
  final connectionState = BluetoothConnectionState.disconnected.obs;
  final services = <BluetoothService>[].obs;
  final logs = <BleLogEntry>[].obs;
  final history = <TempHistoryRecord>[].obs;
  final liveTemperature = Rxn<TemperatureSample>();
  final battery = RxnInt();
  final softwareVersion = RxnString();
  final hardwareVersion = RxnString();
  final charging = RxnBool();
  final deviceTime = Rxn<DateTime>();
  final mtu = 23.obs;
  final pendingLabels = <String>{}.obs;
  final connecting = false.obs;
  final connectionError = RxnString();
  final selectedDevice = Rxn<BluetoothDevice>();
  final historyCapacity = Rxn<TempHistoryCapacity>();
  final exportingHistory = false.obs;
  final HistoryExportService _historyExport = const HistoryExportService();

  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<int>? _mtuSubscription;
  int _nextHistoryId = 0x20;
  int? _activeHistoryId;
  String? _activeHistoryLabel;
  int? _lastPacketIndex;
  bool _historyStarted = false;
  bool _servicesInitializing = false;

  bool get isConnected =>
      connectionState.value == BluetoothConnectionState.connected;
  bool get busy => pendingLabels.isNotEmpty;
  bool get isGoodix =>
      selectedDevice.value?.platformName.contains('Goodix_GUS') ?? false;
  BluetoothCharacteristic? get rx =>
      _ble.findCharacteristic(services, GusProtocol.rxUuid);
  BluetoothCharacteristic? get tx =>
      _ble.findCharacteristic(services, GusProtocol.txUuid);
  String get deviceName => selectedDevice.value?.platformName.isNotEmpty == true
      ? selectedDevice.value!.platformName
      : 'Goodix_GUS';

  @override
  void onInit() {
    super.onInit();
    _adapterSubscription = _ble.adapterState.listen(
      (state) => adapterState.value = state,
    );
    _scanningSubscription = _ble.isScanning.listen(
      (value) => scanning.value = value,
    );
    _ble.scanResults.listen((results) {
      for (final result in results) {
        final name = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.advertisementData.advName;
        if (name.contains('Goodix_GUS') ||
            result.advertisementData.serviceUuids.any(
              (uuid) =>
                  uuid.toString().toLowerCase() ==
                  GusProtocol.serviceUuid.toLowerCase(),
            )) {
          scanDevices[result.device.remoteId.toString()] = DeviceSnapshot(
            device: result.device,
            rssi: result.rssi,
          );
        }
      }
    });
  }

  Future<void> scan() async {
    scanDevices.clear();
    try {
      await _ble.startScan();
      _log('SYS', '开始扫描 Goodix_GUS', false);
    } catch (error) {
      _log('ERR', '扫描失败: $error', true);
    }
  }

  Future<void> stopScan() async {
    await _ble.stopScan();
    _log('SYS', '扫描已停止', false);
  }

  Future<void> openDevice(BluetoothDevice device) async {
    selectedDevice.value = device;
    connectionError.value = null;
    connecting.value = true;
    services.clear();
    pendingLabels.clear();
    pendingLabels.refresh();
    connectionState.value = device.isConnected
        ? BluetoothConnectionState.connected
        : BluetoothConnectionState.disconnected;
    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) async {
      connectionState.value = state;
      if (state == BluetoothConnectionState.connected) {
        connecting.value = false;
        connectionError.value = null;
        _log('SYS', '已连接，开始发现服务', false);
        await discoverServices();
      } else if (state == BluetoothConnectionState.disconnected) {
        if (connecting.value) return;
        services.clear();
        _clearAllPending();
        _log('SYS', '设备已断开', false);
      }
    });
    try {
      if (!device.isConnected) {
        await _ble.connect(device).timeout(const Duration(seconds: 15));
      }
      if (device.isConnected) {
        connectionState.value = BluetoothConnectionState.connected;
        connecting.value = false;
        await discoverServices();
      }
    } catch (error) {
      connecting.value = false;
      connectionState.value = BluetoothConnectionState.disconnected;
      connectionError.value = error.toString();
      _log('ERR', '连接失败: $error', true);
    }
  }

  Future<void> retryConnection() async {
    final device = selectedDevice.value;
    if (device != null) await openDevice(device);
  }

  Future<void> disconnect() async {
    final device = selectedDevice.value;
    if (device == null) return;
    try {
      await _ble.disconnect(device);
      _clearAllPending();
    } catch (error) {
      _log('ERR', '断开失败: $error', true);
    }
  }

  Future<void> discoverServices() async {
    final device = selectedDevice.value;
    if (device == null || !isConnected || _servicesInitializing) return;
    _servicesInitializing = true;
    try {
      services.value = await _ble.discover(device);
      final txCharacteristic = tx;
      if (txCharacteristic != null) {
        await _ble.subscribe(txCharacteristic, _onNotify);
      }
      final negotiated = await _ble.requestMtu(device);
      if (negotiated != null) mtu.value = negotiated;
      _log('SYS', '发现 ${services.length} 个服务，TX 已订阅，MTU ${mtu.value}', false);
      await send('同步设备时间', GusProtocol.setDeviceTime());
    } catch (error) {
      _log('ERR', '服务初始化失败: $error', true);
    } finally {
      _servicesInitializing = false;
    }
  }

  Future<void> send(String label, List<int> frame) async {
    final characteristic = rx;
    if (!isConnected || characteristic == null) {
      _log('ERR', '$label: 未找到 GUS RX 或设备未连接', true);
      return;
    }
    _setPending(label, true);
    _log('TX', '$label  ${GusProtocol.hex(frame)}', false);
    try {
      await _ble.write(characteristic, frame);
    } catch (error) {
      _setPending(label, false);
      _log('ERR', '$label 失败: $error', true);
      return;
    }
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (pendingLabels.contains(label)) {
        _setPending(label, false);
        _log('ERR', '$label 等待响应超时', true);
      }
    });
  }

  Future<void> querySoftware() =>
      send('查询软件版本', GusProtocol.querySoftwareVersion());
  Future<void> queryHardware() =>
      send('查询硬件版本', GusProtocol.queryHardwareVersion());
  Future<void> queryBattery() => send('查询电量', GusProtocol.queryBattery());
  Future<void> queryCharging() => send('查询充电状态', GusProtocol.queryCharging());
  Future<void> queryTime() => send('查询设备时间', GusProtocol.queryDeviceTime());
  Future<void> syncTime() async {
    deviceTime.value = DateTime.now();
    await send('同步设备时间', GusProtocol.setDeviceTime());
  }

  Future<void> startTemperature() =>
      send('开启实时温度', GusProtocol.startTemperature());

  Future<void> queryHistoryCapacity() async =>
      send('查询历史容量', GusProtocol.historyCapacity(_allocateHistoryId()));

  Future<void> readHistory({required bool all}) async {
    final id = _allocateHistoryId();
    _activeHistoryId = id;
    _lastPacketIndex = null;
    _historyStarted = false;
    _activeHistoryLabel = all ? '读取全部历史' : '读取未上传历史';
    history.clear();
    await send(
      all ? '读取全部历史' : '读取未上传历史',
      GusProtocol.readHistory(id, all: all),
    );
  }

  Future<void> stopHistory() async {
    _activeHistoryId = null;
    _activeHistoryLabel = null;
    _historyStarted = false;
    await send('停止历史上传', GusProtocol.stopHistory(_allocateHistoryId()));
  }

  String historyExportText() => _historyExport.buildText(
    deviceName: deviceName,
    deviceId: selectedDevice.value?.remoteId.toString() ?? '',
    records: history.toList(),
  );

  Future<void> shareHistory() async {
    if (history.isEmpty) {
      Get.snackbar('暂无数据', '请先读取温度历史');
      return;
    }
    await _runHistoryExport(() async {
      final name = _historyFileName();
      final bytes = Uint8List.fromList(utf8.encode(historyExportText()));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'text/plain')],
          fileNameOverrides: [name],
          title: '温度历史',
          subject: 'Goodix GUS 温度历史',
        ),
      );
    });
  }

  Future<void> saveHistory() async {
    if (history.isEmpty) {
      Get.snackbar('暂无数据', '请先读取温度历史');
      return;
    }
    await _runHistoryExport(() async {
      final name = _historyFileName();
      final bytes = Uint8List.fromList(utf8.encode(historyExportText()));
      String? path;
      try {
        path = await FileSaver.instance.saveAs(
          name: name,
          bytes: bytes,
          fileExtension: 'txt',
          mimeType: MimeType.text,
        );
      } catch (_) {
        // Web and Linux do not provide a save dialog in file_saver 0.3.x.
        path = await FileSaver.instance.saveFile(
          name: name,
          bytes: bytes,
          fileExtension: 'txt',
          mimeType: MimeType.text,
        );
      }
      if (path != null && path.isNotEmpty) {
        Get.snackbar('保存成功', path);
      }
    });
  }

  Future<void> _runHistoryExport(Future<void> Function() action) async {
    if (exportingHistory.value) return;
    exportingHistory.value = true;
    try {
      await action();
    } catch (error) {
      Get.snackbar('导出失败', '$error');
    } finally {
      exportingHistory.value = false;
    }
  }

  String _historyFileName() =>
      'goodix_temperature_history_${DateTime.now().millisecondsSinceEpoch}';

  int _allocateHistoryId() {
    final id = _nextHistoryId++ & 0xFF;
    if (_nextHistoryId > 0xFF) _nextHistoryId = 0x20;
    return id;
  }

  void _onNotify(List<int> value) {
    if (value.length < 4) return;
    _log(
      'RX',
      '${GusProtocol.describe(value)}  ${GusProtocol.hex(value)}',
      false,
    );
    final cmd = value[2], sub = value[3];
    if (cmd == 0x11 && value.length > 4) {
      final version = String.fromCharCodes(
        value.sublist(4),
      ).replaceAll('\x00', '');
      if (sub == 0) softwareVersion.value = version;
      if (sub == 1) hardwareVersion.value = version;
      _clearPending(sub == 0 ? '查询软件版本' : '查询硬件版本');
    } else if (cmd == 0x12 && value.length > 4) {
      if (sub == 0) battery.value = value[4];
      if (sub == 1) charging.value = value[4] != 0;
      _clearPending(sub == 0 ? '查询电量' : '查询充电状态');
    } else if (cmd == 0x10) {
      if (sub == 1 && value.length >= 12) {
        deviceTime.value = GusProtocol.parseDeviceTime(value);
      } else if (sub == 0) {
        deviceTime.value ??= DateTime.now();
      }
      _clearPending(sub == 0 ? '同步设备时间' : '查询设备时间');
    } else if (cmd == 0x34 && sub == 0 && value.length >= 7) {
      final raw = value[5] | value[6] << 8;
      final signed = raw > 32767 ? raw - 65536 : raw;
      liveTemperature.value = TemperatureSample(
        time: DateTime.now(),
        celsius: value[4] == 1 ? signed / 100 : null,
        valid: value[4] == 1,
      );
      _clearPending('开启实时温度');
    } else if (cmd == GusProtocol.localDataCommand) {
      _handleHistory(value);
    }
  }

  void _handleHistory(List<int> value) {
    if (value[3] == 4) {
      try {
        historyCapacity.value = GusProtocol.parseCapacity(value);
        _clearPending('查询历史容量');
      } catch (error) {
        _log('ERR', '历史容量解析失败: $error', true);
      }
      return;
    }
    if (value[3] == 2) {
      _clearPending('停止历史上传');
      return;
    }
    if ((value[3] != 0 && value[3] != 1) || _activeHistoryId != value[1]) {
      return;
    }
    try {
      final packet = GusProtocol.parsePacket(value);
      if (packet.status != 0) {
        _log(
          'ERR',
          '历史上传失败: ${GusProtocol.historyStatus(packet.status)}',
          true,
        );
        _activeHistoryId = null;
        final failedLabel = _activeHistoryLabel;
        _activeHistoryLabel = null;
        if (failedLabel != null) _clearPending(failedLabel);
        return;
      }
      if (packet.first) {
        _historyStarted = true;
        _lastPacketIndex = null;
        history.clear();
      }
      if (!_historyStarted ||
          (_lastPacketIndex != null &&
              packet.packetIndex != _lastPacketIndex! + 1)) {
        _log('ERR', '历史分包序号异常: ${packet.packetIndex}', true);
        _activeHistoryId = null;
        final failedLabel = _activeHistoryLabel;
        _activeHistoryLabel = null;
        if (failedLabel != null) _clearPending(failedLabel);
        return;
      }
      _lastPacketIndex = packet.packetIndex;
      history.addAll(packet.records);
      history.assignAll(
        [...history]..sort((a, b) => b.unixMs.compareTo(a.unixMs)),
      );
      if (packet.last) {
        _log('SYS', '历史上传完成，共 ${history.length} 条', false);
        _activeHistoryId = null;
        final completedLabel = _activeHistoryLabel;
        _activeHistoryLabel = null;
        _historyStarted = false;
        if (completedLabel != null) _clearPending(completedLabel);
      }
    } catch (error) {
      _log('ERR', '历史分包解析失败: $error', true);
    }
  }

  void _setPending(String label, bool value) {
    if (value) {
      pendingLabels.add(label);
    } else {
      pendingLabels.remove(label);
    }
    pendingLabels.refresh();
  }

  void _clearPending(String label) => _setPending(label, false);

  void _clearAllPending() {
    if (pendingLabels.isEmpty) return;
    pendingLabels.clear();
    pendingLabels.refresh();
  }

  void _log(String direction, String message, bool isError) {
    logs.insert(
      0,
      BleLogEntry(
        time: DateTime.now(),
        direction: direction,
        message: message,
        isError: isError,
      ),
    );
    if (logs.length > 300) logs.removeLast();
  }

  @override
  void onClose() {
    _adapterSubscription?.cancel();
    _scanningSubscription?.cancel();
    _connectionSubscription?.cancel();
    _mtuSubscription?.cancel();
    _ble.dispose();
    super.onClose();
  }
}
