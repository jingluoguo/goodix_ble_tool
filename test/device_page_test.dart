import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:goodix_ble_tool/controllers/ble_controller.dart';
import 'package:goodix_ble_tool/core/app_theme.dart';
import 'package:goodix_ble_tool/models/ble_models.dart';
import 'package:goodix_ble_tool/pages/device_page.dart';
import 'package:goodix_ble_tool/services/gus_protocol.dart';

/// 造一个「已连接且各项都有值」的控制器，不碰任何 BLE 平台通道。
BleController connectedController() {
  final controller = BleController();
  controller.hasSession.value = true;
  controller.connectionState.value = BluetoothConnectionState.connected;
  controller.battery.value = 88;
  controller.mtu.value = 247;
  controller.softwareVersion.value = 'SW_V1.0.0';
  controller.hardwareVersion.value = 'HW_V1.0.0';
  controller.charging.value = true;
  controller.deviceTime.value = DateTime(2026, 9, 15, 17, 49, 59);
  controller.liveTemperature.value = TemperatureSample(
    time: DateTime(2026, 9, 15),
    celsius: 34.75,
    valid: true,
  );
  controller.heartRate.value = 77;
  controller.hrv.value = 31;
  controller.spo2.value = 98;
  return controller;
}

Future<void> pumpPage(
  WidgetTester tester,
  BleController controller,
  Size size, {
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: DevicePage(controller: controller),
    ),
  );
  // 页面里有转圈的进度指示时 pumpAndSettle 永远不会静止，只 pump 一帧。
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('宽屏下控制台完整渲染（无溢出）', (tester) async {
    final controller = connectedController();
    await pumpPage(tester, controller, const Size(1440, 900));

    expect(find.text('设备控制台'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    // 顶部状态条：设备信息与实时指标合并
    // （这几个标签在快捷命令按钮里也有同名文案，故用 findsWidgets）
    expect(find.text('软件版本'), findsWidgets);
    expect(find.text('硬件版本'), findsWidgets);
    expect(find.text('充电状态'), findsWidgets);
    expect(find.text('设备时间'), findsWidgets);
    expect(find.text('SW_V1.0.0'), findsOneWidget);
    expect(find.text('247'), findsOneWidget);
    // 测量按钮下排显示实际数值
    expect(find.text('温度测量'), findsOneWidget);
    expect(find.text('心率测量'), findsOneWidget);
    expect(find.text('HRV测量'), findsOneWidget);
    expect(find.text('血氧测量'), findsOneWidget);
    expect(find.text('77 bpm'), findsOneWidget);
    expect(find.text('31 ms'), findsOneWidget);
    expect(find.text('98 %'), findsOneWidget);
    // 历史与日志合并成一个 Tab 面板
    expect(find.text('温度历史 · 0'), findsOneWidget);
    expect(find.text('联调日志 · 0'), findsOneWidget);
  });

  testWidgets('窄屏（手机宽度）下同样不溢出', (tester) async {
    final controller = connectedController();
    await pumpPage(tester, controller, const Size(400, 900));

    expect(find.text('设备控制台'), findsOneWidget);
    expect(find.text('心率测量'), findsOneWidget);
    expect(find.text('温度历史 · 0'), findsOneWidget);
  });

  testWidgets('测量进行中，该按钮原地变成停止测量', (tester) async {
    final controller = connectedController();
    controller.measureKind.value = MeasureKind.hr;
    controller.measureStartedAt.value = DateTime.now();
    await pumpPage(tester, controller, const Size(1440, 900));

    expect(find.text('停止测量'), findsOneWidget);
    expect(find.text('心率测量'), findsNothing);
    expect(find.textContaining('采集中'), findsOneWidget);
    // 其他测量项此时被串行互斥禁用
    final hrvButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('HRV测量'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(hrvButton.onPressed, isNull);
  });

  testWidgets('数值未测过时显示 --', (tester) async {
    final controller = BleController();
    controller.hasSession.value = true;
    controller.connectionState.value = BluetoothConnectionState.connected;
    await pumpPage(tester, controller, const Size(1440, 900));

    expect(find.text('心率测量'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
  });

  testWidgets('断连后仍保留控制台，只禁用命令下发', (tester) async {
    final controller = connectedController();
    controller.connectionState.value = BluetoothConnectionState.disconnected;
    await pumpPage(tester, controller, const Size(1440, 900));

    // 页面没有整页切成「设备已断开」占位
    expect(find.text('设备控制台'), findsOneWidget);
    expect(find.text('已断开'), findsOneWidget);
    expect(find.textContaining('命令下发已禁用'), findsOneWidget);
    // 数据仍在
    expect(find.text('77 bpm'), findsOneWidget);
    expect(find.text('温度历史 · 0'), findsOneWidget);
    // 命令与测量按钮被禁用
    final measureButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('心率测量'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(measureButton.onPressed, isNull);
    final queryButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('查询电量'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(queryButton.onPressed, isNull);
  });

  testWidgets('从未连上时仍走整页占位', (tester) async {
    final controller = BleController();
    // 进入设备页的初始状态：openDevice 已把 connecting 置起
    controller.connecting.value = true;
    await pumpPage(tester, controller, const Size(1440, 900), settle: false);

    expect(find.text('设备控制台'), findsNothing);
    expect(find.text('正在连接…'), findsOneWidget);
  });

  testWidgets('首次连接失败时整页占位并给出重连入口', (tester) async {
    final controller = BleController();
    controller.connectionError.value = 'TimeoutException: 连接超时';
    await pumpPage(tester, controller, const Size(1440, 900));

    expect(find.text('设备控制台'), findsNothing);
    expect(find.text('连接失败'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);
  });

  testWidgets('切换 Tab 可看到联调日志', (tester) async {
    final controller = connectedController();
    controller.logs.add(
      BleLogEntry(
        time: DateTime(2026, 9, 15, 17, 50),
        direction: 'RX',
        message: '测量响应(HR) 结果帧  HR=77 bpm',
      ),
    );
    await pumpPage(tester, controller, const Size(1440, 900));

    expect(find.text('联调日志 · 1'), findsOneWidget);
    await tester.tap(find.text('联调日志 · 1'));
    await tester.pumpAndSettle();

    expect(find.text('测量响应(HR) 结果帧  HR=77 bpm'), findsOneWidget);
    expect(find.text('尚无历史数据'), findsNothing);
  });

  testWidgets('顶部状态条改成两行（宽屏 4+3），不再横向滚动', (tester) async {
    final controller = connectedController();
    await pumpPage(tester, controller, const Size(1440, 900));

    // 这几个标签在快捷命令按钮里也有同名文案，状态条在树里更靠前，取 first。
    const labels = ['电量', '体温', 'MTU', '软件版本', '硬件版本', '充电状态', '设备时间'];
    final rows = <double, List<String>>{};
    for (final label in labels) {
      final finder = find.text(label).first;
      rows.putIfAbsent(tester.getTopLeft(finder).dy, () => []).add(label);
      // 每个指标都要完整落在可视宽度内（原来的单行实现会把它挤出屏幕）
      expect(tester.getTopLeft(finder).dx, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(finder).dx, lessThanOrEqualTo(1440));
    }

    expect(rows, hasLength(2), reason: '七个指标应恰好铺成两行');
    expect(
      rows.values.map((v) => v.length).toList()..sort(),
      [3, 4],
      reason: '两行应分别为 4 个和 3 个指标',
    );
  });

  testWidgets('顶部状态条不含横向可滚动组件（不会出现横向滚动条）', (tester) async {
    final controller = connectedController();
    await pumpPage(tester, controller, const Size(1440, 900));

    // 原实现是「单行横向 ListView + Scrollbar(thumbVisibility: true)」，
    // 会在状态条下方常驻一条横向滚动条。现在从状态条往上追溯，
    // 所有祖先可滚动组件都必须是纵向的。
    final ancestors = tester
        .widgetList<Scrollable>(
          find.ancestor(
            of: find.text('MTU'),
            matching: find.byType(Scrollable),
          ),
        )
        .toList();
    expect(ancestors, isNotEmpty, reason: '应能追溯到页面的纵向列表');
    for (final scrollable in ancestors) {
      expect(
        axisDirectionToAxis(scrollable.axisDirection),
        Axis.vertical,
        reason: '状态条与页面根之间不应出现横向可滚动组件',
      );
    }

    // 也不应再有任何显式 Material Scrollbar 包着状态条。
    // （桌面端自动注入的是 RawScrollbar，不会命中这里，所以断言是安全的）
    expect(
      find.ancestor(of: find.text('MTU'), matching: find.byType(Scrollbar)),
      findsNothing,
    );
  });

  testWidgets('分享与下载挂在 tab 栏上，并跟着当前 Tab 切换', (tester) async {
    final controller = connectedController();
    controller.history.add(
      const TempHistoryRecord(
        seq: 1,
        unixMs: 1789473600000,
        temperatureX100: 3650,
        valid: true,
      ),
    );
    await pumpPage(tester, controller, const Size(1440, 900));

    // tester.widget 在匹配数 != 1 时会抛错，等于同时断言「有且只有一个」。
    IconButton exportButton(IconData icon) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

    // 位置：两个按钮都落在 tab 栏的纵向范围内，且在 tab 标签右侧
    final tabBar = tester.getRect(find.byType(TabBar));
    for (final icon in [Icons.share_outlined, Icons.file_download_outlined]) {
      final rect = tester.getRect(find.byIcon(icon));
      expect(rect.center.dy, greaterThan(tabBar.top));
      expect(rect.center.dy, lessThan(tabBar.bottom));
      expect(rect.left, greaterThan(tabBar.right));
    }

    // 温度历史 Tab：有数据 → 分享 / 下载可用
    expect(find.text('温度历史 · 1'), findsOneWidget);
    expect(exportButton(Icons.share_outlined).onPressed, isNotNull);
    expect(exportButton(Icons.file_download_outlined).onPressed, isNotNull);

    // 联调日志 Tab：日志为空 → 按钮仍在，但置灰
    await tester.tap(find.text('联调日志 · 0'));
    await tester.pumpAndSettle();
    expect(exportButton(Icons.share_outlined).onPressed, isNull);
    expect(exportButton(Icons.file_download_outlined).onPressed, isNull);

    // 有日志之后即可导出（导出的是本地缓存，不依赖连接状态）
    controller.logs.add(
      BleLogEntry(
        time: DateTime(2026, 9, 15, 17, 50),
        direction: 'RX',
        message: '测试日志',
      ),
    );
    await tester.pumpAndSettle();
    expect(exportButton(Icons.share_outlined).onPressed, isNotNull);
    expect(exportButton(Icons.file_download_outlined).onPressed, isNotNull);
  });

  testWidgets('断连后历史与日志仍可导出', (tester) async {
    final controller = connectedController();
    controller.connectionState.value = BluetoothConnectionState.disconnected;
    controller.logs.add(
      BleLogEntry(
        time: DateTime(2026, 9, 15, 17, 50),
        direction: 'RX',
        message: '断开前的日志',
      ),
    );
    await pumpPage(tester, controller, const Size(1440, 900));

    await tester.tap(find.text('联调日志 · 1'));
    await tester.pumpAndSettle();

    final save = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.file_download_outlined),
    );
    expect(save.onPressed, isNotNull);
  });
}
