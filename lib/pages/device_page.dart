import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ble_controller.dart';
import '../core/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/status_pill.dart';

class DevicePage extends StatelessWidget {
  final BleController controller;
  const DevicePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.deviceName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        actions: [
          Obx(
            () => TextButton.icon(
              onPressed: controller.isConnected ? controller.disconnect : null,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('断开'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(
        () => controller.isConnected
            ? _connectedBody(context)
            : _waitingBody(context),
      ),
    );
  }

  Widget _waitingBody(BuildContext context) => Center(
    child: Obx(() {
      final error = controller.connectionError.value;
      if (error != null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bluetooth_disabled_outlined,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 14),
              const Text(
                '连接失败',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: controller.retryConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('重新连接'),
              ),
            ],
          ),
        );
      }
      if (!controller.connecting.value) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bluetooth_disabled_outlined,
                size: 42,
                color: AppTheme.muted,
              ),
              const SizedBox(height: 14),
              const Text(
                '设备已断开',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: controller.retryConnection,
                icon: const Icon(Icons.refresh),
                label: const Text('重新连接'),
              ),
            ],
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          const Text('正在连接…'),
        ],
      );
    }),
  );

  Widget _connectedBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final main = ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _deviceHeader(),
            const SizedBox(height: 16),
            _metrics(),
            const SizedBox(height: 16),
            _deviceDetails(),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _commandPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _historyPanel()),
                ],
              )
            else ...[
              _commandPanel(),
              const SizedBox(height: 16),
              _historyPanel(),
            ],
            const SizedBox(height: 16),
            _protocolPanel(),
          ],
        );
        return main;
      },
    );
  }

  Widget _deviceHeader() => Obx(
    () => Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设备控制台',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                controller.selectedDevice.value?.remoteId.toString() ?? '',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const StatusPill(label: '已连接', active: true),
      ],
    ),
  );

  Widget _metrics() => Obx(
    () => Row(
      children: [
        Expanded(
          child: _metric(
            '电量',
            controller.battery.value == null
                ? '--'
                : '${controller.battery.value}%',
            Icons.battery_5_bar_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metric(
            '实时温度',
            controller.liveTemperature.value?.celsius == null
                ? '--'
                : '${controller.liveTemperature.value!.celsius!.toStringAsFixed(2)}°',
            Icons.thermostat_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metric(
            'MTU',
            '${controller.mtu.value}',
            Icons.swap_vert_circle_outlined,
          ),
        ),
      ],
    ),
  );

  Widget _metric(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mint, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _deviceDetails() => Obx(
    () => SectionCard(
      title: '设备信息',
      subtitle: '来自设备响应的最新值',
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        children: [
          _detail('软件版本', controller.softwareVersion.value ?? '--'),
          _detail('硬件版本', controller.hardwareVersion.value ?? '--'),
          _detail(
            '充电状态',
            controller.charging.value == null
                ? '--'
                : controller.charging.value!
                ? '充电中'
                : '未充电',
          ),
          _detail(
            '设备时间',
            controller.deviceTime.value?.toLocal().toString() ?? '--',
          ),
        ],
      ),
    ),
  );

  Widget _detail(String label, String value) => SizedBox(
    width: 210,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
      ],
    ),
  );

  Widget _commandPanel() => SectionCard(
    title: '快速命令',
    subtitle: '所有命令均通过 GUS RX 写入完整业务帧',
    trailing: Obx(
      () => controller.pendingLabels.isNotEmpty
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SizedBox.shrink(),
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _command('查询软件版本', '软件版本', Icons.code, controller.querySoftware),
        _command(
          '查询硬件版本',
          '硬件版本',
          Icons.memory_outlined,
          controller.queryHardware,
        ),
        _command('查询电量', '查询电量', Icons.battery_std, controller.queryBattery),
        _command('查询充电状态', '充电状态', Icons.power, controller.queryCharging),
        _command('查询设备时间', '设备时间', Icons.schedule, controller.queryTime),
        _command('同步设备时间', '同步时间', Icons.sync, controller.syncTime),
        _command(
          '开启实时温度',
          '开启温度',
          Icons.thermostat,
          controller.startTemperature,
        ),
      ],
    ),
  );

  Widget _command(
    String pendingLabel,
    String label,
    IconData icon,
    VoidCallback action,
  ) => Obx(() {
    final waiting = controller.pendingLabels.contains(pendingLabel);
    return OutlinedButton.icon(
      onPressed: controller.isConnected && !waiting ? action : null,
      icon: waiting
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: Text(waiting ? '等待响应' : label),
    );
  });

  Widget _historyPanel() => Obx(
    () => SectionCard(
      title: '温度历史',
      subtitle: '读取前已自动尝试协商 MTU 247',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${controller.history.length} 条',
            style: const TextStyle(
              color: AppTheme.mint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Obx(
            () => IconButton(
              onPressed: controller.exportingHistory.value
                  ? null
                  : controller.shareHistory,
              tooltip: '分享 TXT',
              icon: controller.exportingHistory.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined, size: 19),
            ),
          ),
          Obx(
            () => IconButton(
              onPressed: controller.exportingHistory.value
                  ? null
                  : controller.saveHistory,
              tooltip: '保存 TXT',
              icon: const Icon(Icons.save_alt_outlined, size: 19),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _historyAction(
                  '读取全部历史',
                  Icons.download_outlined,
                  () => controller.readHistory(all: true),
                  '读取全部',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _historyAction(
                  '读取未上传历史',
                  Icons.sync_alt,
                  () => controller.readHistory(all: false),
                  '未上传',
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final waiting = controller.pendingLabels.contains('停止历史上传');
                return IconButton(
                  onPressed: waiting ? null : controller.stopHistory,
                  tooltip: '停止上传',
                  icon: waiting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          _historyAction(
            '查询历史容量',
            Icons.data_usage_outlined,
            controller.queryHistoryCapacity,
            '查询历史容量',
          ),
          const SizedBox(height: 12),
          if (controller.historyCapacity.value != null)
            Text(
              '容量 ${controller.historyCapacity.value!.count} 条 · ${controller.historyCapacity.value!.fileSize} bytes',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: controller.history.isEmpty
                ? const Center(
                    child: Text(
                      '尚无历史数据',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  )
                : ListView.separated(
                    itemCount: controller.history.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final record = controller.history[index];
                      final time = DateTime.fromMillisecondsSinceEpoch(
                        record.unixMs,
                        isUtc: true,
                      ).toLocal();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text(
                          '#${record.seq}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: AppTheme.muted,
                          ),
                        ),
                        title: Text(
                          record.valid
                              ? '${record.celsius!.toStringAsFixed(2)} °C'
                              : '无效温度',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _protocolPanel() => Obx(
    () => SectionCard(
      title: '联调日志',
      subtitle: 'TX 写入 · RX Notify · SYS 状态',
      trailing: Text(
        '${controller.logs.length}',
        style: const TextStyle(color: AppTheme.muted),
      ),
      child: SizedBox(
        height: 240,
        child: controller.logs.isEmpty
            ? const Center(
                child: Text('等待设备响应', style: TextStyle(color: AppTheme.muted)),
              )
            : ListView.builder(
                itemCount: controller.logs.length,
                itemBuilder: (_, index) {
                  final entry = controller.logs[index];
                  final color = entry.isError
                      ? Colors.red
                      : entry.direction == 'RX'
                      ? AppTheme.mint
                      : entry.direction == 'TX'
                      ? AppTheme.orange
                      : AppTheme.muted;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.direction.padRight(3),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.message,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ),
  );

  Widget _historyAction(
    String pendingLabel,
    IconData icon,
    VoidCallback action,
    String text,
  ) => Obx(() {
    final waiting = controller.pendingLabels.contains(pendingLabel);
    return OutlinedButton.icon(
      onPressed: waiting ? null : action,
      icon: waiting
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 17),
      label: Text(waiting ? '等待响应' : text),
    );
  });
}
