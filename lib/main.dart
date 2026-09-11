import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

import 'controllers/ble_controller.dart';
import 'core/app_theme.dart';
import 'pages/home_page.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.warning);
  runApp(const GoodixBleApp());
}

class GoodixBleApp extends StatelessWidget {
  const GoodixBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TRCK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: BindingsBuilder(() {
        Get.put(BleController());
      }),
      home: const HomePage(),
    );
  }
}
