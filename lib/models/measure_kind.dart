/// 测量项。
///
/// [temperature] 走 0x34/0x00，同步直读、不受测量互斥限制；
/// 其余三项是异步测量链：受理帧（0x03）→ 结果帧（0x01），必须串行。
///
/// 本文件保持纯 Dart（不依赖 Flutter），协议层可直接引用并单测。
enum MeasureKind { temperature, hr, hrv, spo2 }

extension MeasureKindInfo on MeasureKind {
  String get label => switch (this) {
    MeasureKind.temperature => '温度测量',
    MeasureKind.hr => '心率测量',
    MeasureKind.hrv => 'HRV测量',
    MeasureKind.spo2 => '血氧测量',
  };

  /// 固件默认测量时长（秒），仅用于界面进度提示。
  int get defaultDurationS => switch (this) {
    MeasureKind.temperature => 0,
    MeasureKind.hr => 30,
    MeasureKind.hrv => 120,
    MeasureKind.spo2 => 60,
  };

  /// 等待结果帧的超时时间，取自联调手册建议值。
  Duration get timeout => switch (this) {
    MeasureKind.temperature => const Duration(seconds: 8),
    MeasureKind.hr => const Duration(seconds: 35),
    MeasureKind.hrv => const Duration(seconds: 125),
    MeasureKind.spo2 => const Duration(seconds: 65),
  };

  /// 是否占用测量链（HR / HRV / SpO2 三者互斥）。
  bool get occupiesChain => this != MeasureKind.temperature;
}
