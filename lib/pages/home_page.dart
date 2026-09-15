import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

import '../controllers/ble_controller.dart';
import '../core/app_theme.dart';
import '../models/ble_models.dart';
import '../widgets/device_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';
import 'device_page.dart';

class HomePage extends GetView<BleController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TRCK',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Obx(
            () => StatusPill(
              label: _adapterLabel(controller.adapterState.value),
              active: controller.adapterState.value == BluetoothAdapterState.on,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 1100
              ? 1060.0
              : constraints.maxWidth;
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 40),
                children: [
                  Obx(() => _scanCard()),
                  const SizedBox(height: 16),
                  _workflowCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _adapterLabel(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        return '蓝牙已开启';
      case BluetoothAdapterState.off:
        return '蓝牙已关闭';
      case BluetoothAdapterState.unauthorized:
        return '需要蓝牙权限';
      default:
        return '蓝牙状态检测中';
    }
  }

  Widget _scanCard() {
    final devices = controller.scanDevices.values.toList();
    return SectionCard(
      title: '附近的 Goodix 设备',
      subtitle: controller.scanning.value
          ? '正在监听 Goodix 广播'
          : '仅显示设备名或服务 UUID 匹配的设备',
      trailing: controller.scanning.value
          ? FilledButton.icon(
              onPressed: controller.stopScan,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('停止'),
            )
          : FilledButton.icon(
              onPressed: controller.scan,
              icon: const Icon(Icons.radar, size: 16),
              label: const Text('扫描'),
            ),
      child: devices.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      controller.adapterState.value == BluetoothAdapterState.on
                          ? Icons.radar
                          : Icons.bluetooth_disabled,
                      size: 40,
                      color: AppTheme.mint.withValues(alpha: .7),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      controller.adapterState.value == BluetoothAdapterState.on
                          ? '点击扫描，寻找 TRCK'
                          : '请先开启系统蓝牙',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < devices.length; i++) ...[
                  DeviceTile(
                    device: devices[i],
                    onTap: () => _openDevice(devices[i]),
                  ),
                  if (i != devices.length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }

  void _openDevice(DeviceSnapshot device) {
    Get.to(() => DevicePage(controller: controller));
    controller.openDevice(device.device);
  }

  Widget _workflowCard() => SectionCard(
    title: '推荐联调顺序',
    subtitle: '与固件参数说明文档保持一致',
    child: Row(
      children: [
        for (final item in const [
          ('01', '扫描'),
          ('02', '连接'),
          ('03', '订阅 TX'),
          ('04', '发送帧'),
          ('05', '校验响应'),
        ])
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F1ED),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.$2,
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
