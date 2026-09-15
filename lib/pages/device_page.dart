import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ble_controller.dart';
import '../core/app_theme.dart';
import '../models/ble_models.dart';
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
      body: Obx(() {
        // 连过又断了：控制台整页保留（日志 / 历史 / 测量结果都还在），
        // 只是命令下发被置灰；只有「从没连上」时才整页占位。
        if (!controller.isConnected && !controller.hasSession.value) {
          return _waitingBody(context);
        }
        return _consoleBody(context);
      }),
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

  Widget _consoleBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 980;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _deviceHeader(),
            const SizedBox(height: 14),
            _statusStrip(),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _commandPanel()),
                  const SizedBox(width: 16),
                  Expanded(child: _tabPanel()),
                ],
              )
            else ...[
              _commandPanel(),
              const SizedBox(height: 16),
              _tabPanel(),
            ],
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ 顶部状态区

  Widget _deviceHeader() => Obx(() {
    final connected = controller.isConnected;
    final connecting = controller.connecting.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            StatusPill(
              label: connected ? '已连接' : (connecting ? '连接中' : '已断开'),
              active: connected,
            ),
          ],
        ),
        if (!connected) ...[
          const SizedBox(height: 12),
          _offlineBanner(
            connecting: connecting,
            error: controller.connectionError.value,
          ),
        ],
      ],
    );
  });

  Widget _offlineBanner({required bool connecting, String? error}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.orange.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          connecting ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
          size: 18,
          color: AppTheme.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            connecting
                ? '正在重新连接…'
                : error == null
                ? '设备已断开：命令下发已禁用，历史数据与联调日志仍可查看'
                : '重新连接失败：$error',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.ink),
          ),
        ),
        if (!connecting)
          TextButton.icon(
            onPressed: controller.retryConnection,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新连接'),
          ),
      ],
    ),
  );

  /// 设备信息与实时指标合并展示：宽屏铺成两行四列，窄屏退化为两列多行。
  /// 末行不足一列时用等宽空位补齐，保证上下行列宽对齐。
  Widget _statusStrip() => Obx(() {
    final items = <(String, String, IconData)>[
      (
        '电量',
        controller.battery.value == null
            ? '--'
            : '${controller.battery.value}%',
        Icons.battery_5_bar_outlined,
      ),
      (
        '体温',
        controller.liveTemperature.value?.celsius == null
            ? '--'
            : '${controller.liveTemperature.value!.celsius!.toStringAsFixed(2)} °C',
        Icons.thermostat_outlined,
      ),
      ('MTU', '${controller.mtu.value}', Icons.swap_vert_circle_outlined),
      ('软件版本', controller.softwareVersion.value ?? '--', Icons.code),
      ('硬件版本', controller.hardwareVersion.value ?? '--', Icons.memory_outlined),
      (
        '充电状态',
        controller.charging.value == null
            ? '--'
            : (controller.charging.value! ? '充电中' : '未充电'),
        Icons.power,
      ),
      ('设备时间', _formatTime(controller.deviceTime.value), Icons.schedule),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // 单元格太窄会让数值被 FittedBox 压成小字，所以窄屏降到两列。
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final rows = <List<(String, String, IconData)?>>[];
        for (var start = 0; start < items.length; start += columns) {
          rows.add([
            for (var i = start; i < start + columns; i++)
              i < items.length ? items[i] : null,
          ]);
        }
        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              _stripRow(rows[r]),
            ],
          ],
        );
      },
    );
  });

  Widget _stripRow(List<(String, String, IconData)?> cells) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 10));
      final cell = cells[i];
      children.add(
        Expanded(
          child: cell == null
              ? const SizedBox.shrink()
              : _stripCard(cell.$1, cell.$2, cell.$3),
        ),
      );
    }
    return Row(children: children);
  }

  Widget _stripCard(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mint, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: value,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String _formatTime(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  // ---------------------------------------------------------------- 命令区

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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
            _command(
              '查询电量',
              '查询电量',
              Icons.battery_std,
              controller.queryBattery,
            ),
            _command('查询充电状态', '充电状态', Icons.power, controller.queryCharging),
            _command('查询设备时间', '设备时间', Icons.schedule, controller.queryTime),
            _command('同步设备时间', '同步时间', Icons.sync, controller.syncTime),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        const Text(
          '测量',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'HR / HRV / SpO2 需串行执行；体温为同步直读，可随时插队',
          style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final kind in MeasureKind.values) _measureTile(kind)],
        ),
        _measureHint(),
      ],
    ),
  );

  IconData _measureIcon(MeasureKind kind) => switch (kind) {
    MeasureKind.temperature => Icons.thermostat,
    MeasureKind.hr => Icons.monitor_heart_outlined,
    MeasureKind.hrv => Icons.graphic_eq,
    MeasureKind.spo2 => Icons.water_drop_outlined,
  };

  /// 还没测过时返回 null，界面显示 `--`。
  String? _measureValueText(MeasureKind kind) => switch (kind) {
    MeasureKind.temperature =>
      controller.liveTemperature.value?.celsius == null
          ? null
          : '${controller.liveTemperature.value!.celsius!.toStringAsFixed(2)} °C',
    MeasureKind.hr =>
      controller.heartRate.value == null
          ? null
          : '${controller.heartRate.value} bpm',
    MeasureKind.hrv =>
      controller.hrv.value == null ? null : '${controller.hrv.value} ms',
    MeasureKind.spo2 =>
      controller.spo2.value == null ? null : '${controller.spo2.value} %',
  };

  /// 测量按钮：上排是名称，下排直接显示该测量项的实际数值；
  /// 开跑后原地变成「停止测量」（发 0x38/0x00），下排改为采集中计时。
  Widget _measureTile(MeasureKind kind) => Obx(() {
    final running = controller.measureKind.value == kind;
    if (running) {
      final stopping = controller.pendingLabels.contains('停止测量');
      return _measureTileShell(
        onPressed: stopping ? null : controller.stopMeasure,
        filled: true,
        icon: Icons.stop_circle_outlined,
        label: stopping ? '正在停止' : '停止测量',
        detail: '采集中 ${controller.measureElapsed.value}s',
        detailColor: Colors.white,
      );
    }
    final waiting = controller.pendingLabels.contains(kind.label);
    final value = _measureValueText(kind);
    return _measureTileShell(
      onPressed: controller.canMeasure(kind) && !waiting
          ? () => controller.startMeasure(kind)
          : null,
      filled: false,
      icon: _measureIcon(kind),
      label: waiting ? '等待响应' : kind.label,
      detail: value ?? '--',
      detailColor: value == null ? AppTheme.muted : AppTheme.mint,
    );
  });

  Widget _measureTileShell({
    required VoidCallback? onPressed,
    required bool filled,
    required IconData icon,
    required String label,
    required String detail,
    required Color detailColor,
  }) {
    final child = SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: detailColor,
            ),
          ),
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.orange,
          foregroundColor: Colors.white,
          padding: padding,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(padding: padding),
      child: child,
    );
  }

  /// 测量失败时给一行提示；成功时数值已经在按钮下排，不重复占位。
  Widget _measureHint() => Obx(() {
    final outcome = controller.measureOutcome.value;
    if (outcome == null || outcome.valid) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: Colors.redAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${outcome.kind.label}：${outcome.summary}',
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  });

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

  // ------------------------------------------------------- 历史 / 日志 Tab

  Widget _tabPanel() => DefaultTabController(
    length: 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => TabBar(
                      indicatorColor: AppTheme.mint,
                      labelColor: AppTheme.ink,
                      unselectedLabelColor: AppTheme.muted,
                      labelStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(text: '温度历史 · ${controller.history.length}'),
                        Tab(text: '联调日志 · ${controller.logs.length}'),
                      ],
                    ),
                  ),
                ),
                // 导出按钮挂在 tab 栏右侧、跟着当前 Tab 走。要拿到 DefaultTabController
                // 的 controller 就必须在其子树里取，所以这里套一层 Builder。
                Builder(
                  builder: (context) =>
                      _tabExportActions(DefaultTabController.of(context)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 330,
              child: TabBarView(children: [_historyTab(), _logTab()]),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _historyTab() => Obx(
    () => Column(
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
                onPressed: !controller.isConnected || waiting
                    ? null
                    : controller.stopHistory,
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
        Row(
          children: [
            _historyAction(
              '查询历史容量',
              Icons.data_usage_outlined,
              controller.queryHistoryCapacity,
              '查询历史容量',
            ),
            if (controller.historyCapacity.value != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '容量 ${controller.historyCapacity.value!.count} 条 · '
                  '${controller.historyCapacity.value!.fileSize} bytes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
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
                        '${time.month}/${time.day} '
                        '${time.hour.toString().padLeft(2, '0')}:'
                        '${time.minute.toString().padLeft(2, '0')}',
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
  );

  Widget _logTab() => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          controller.logs.isEmpty
              ? '暂无日志'
              : '共 ${controller.logs.length} 条 · 最新在前',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: controller.logs.isEmpty
              ? const Center(
                  child: Text(
                    '等待设备响应',
                    style: TextStyle(color: AppTheme.muted),
                  ),
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
      ],
    ),
  );

  /// tab 栏右侧的导出入口：按当前选中的 Tab 决定导出对象，并跟着 Tab 切换刷新。
  ///
  /// `TabController` 是 `ChangeNotifier`，`_changeIndex` 里会 `notifyListeners()`，
  /// 所以这里用 `ListenableBuilder` 订阅 index 变化。
  Widget _tabExportActions(TabController tabs) => ListenableBuilder(
    listenable: tabs,
    builder: (_, _) {
      final historyTab = tabs.index == 0;
      return _exportActions(
        hasData: () => historyTab
            ? controller.history.isNotEmpty
            : controller.logs.isNotEmpty,
        onShare: historyTab ? controller.shareHistory : controller.shareLogs,
        onSave: historyTab ? controller.saveHistory : controller.saveLogs,
      );
    },
  );

  /// 温度历史 / 联调日志共用的「分享 + 下载」按钮组。
  /// 导出的是本地已缓存数据，所以不跟随连接状态置灰，断开后仍可导出。
  Widget _exportActions({
    required bool Function() hasData,
    required VoidCallback onShare,
    required VoidCallback onSave,
  }) => Obx(() {
    final busy = controller.exporting.value;
    final enabled = !busy && hasData();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
        ],
        IconButton(
          onPressed: enabled ? onShare : null,
          tooltip: '分享 TXT',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.share_outlined, size: 19),
        ),
        IconButton(
          onPressed: enabled ? onSave : null,
          tooltip: '下载 TXT',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.file_download_outlined, size: 19),
        ),
      ],
    );
  });

  Widget _historyAction(
    String pendingLabel,
    IconData icon,
    VoidCallback action,
    String text,
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
      label: Text(waiting ? '等待响应' : text),
    );
  });
}
