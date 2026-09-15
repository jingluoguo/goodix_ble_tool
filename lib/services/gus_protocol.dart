import 'dart:typed_data';

import '../models/measure_kind.dart';

class TempHistoryRecord {
  final int seq;
  final int unixMs;
  final int temperatureX100;
  final bool valid;

  const TempHistoryRecord({
    required this.seq,
    required this.unixMs,
    required this.temperatureX100,
    required this.valid,
  });
  double? get celsius => valid ? temperatureX100 / 100 : null;
}

class TempHistoryPacket {
  final int frameId;
  final int status;
  final int flags;
  final int packetIndex;
  final List<TempHistoryRecord> records;

  const TempHistoryPacket({
    required this.frameId,
    required this.status,
    required this.flags,
    required this.packetIndex,
    required this.records,
  });
  bool get first => flags & 0x01 != 0;
  bool get last => flags & 0x02 != 0;
}

class TempHistoryCapacity {
  final int count;
  final int fileSize;
  final int status;
  const TempHistoryCapacity({
    required this.count,
    required this.fileSize,
    required this.status,
  });
}

/// 测量响应帧（0x31 / 0x32 / 0x33）。
///
/// 帧布局：`[0] type [1] frame_id [2] cmd [3] subcmd [4] status [5..] data`
class MeasureResponse {
  final int frameId;
  final int cmd;
  final int subcmd;
  final int status;
  final int? hr;
  final int? hrv;
  final int? spo2;

  const MeasureResponse({
    required this.frameId,
    required this.cmd,
    required this.subcmd,
    required this.status,
    this.hr,
    this.hrv,
    this.spo2,
  });

  /// 0x03 受理确认帧：数据位全 0，此时才开始真正采集。
  bool get accepted => status == 0x03;

  /// 0x01 结果帧：不代表数据有效，必须再判数据位是否为 0。
  bool get isResult => status == 0x01;

  /// 0x00 未佩戴 / 测量中断，结果无效。
  bool get aborted => status == 0x00;

  /// 0x04 繁忙，本次不执行（上一条测量链还没结束）。
  bool get rejected => status == 0x04;
}

class GusProtocol {
  static const serviceUuid = 'A6ED0201-D344-460A-8075-B9E8EC90D71B';
  static const txUuid = 'A6ED0202-D344-460A-8075-B9E8EC90D71B';
  static const rxUuid = 'A6ED0203-D344-460A-8075-B9E8EC90D71B';
  static const flowUuid = 'A6ED0204-D344-460A-8075-B9E8EC90D71B';
  static const localDataCommand = 0x36;
  static const hrHrvCommand = 0x31;
  static const spo2Command = 0x32;
  static const hrCommand = 0x33;
  static const temperatureCommand = 0x34;
  static const stopMeasureCommand = 0x38;

  static List<int> frame(
    int id,
    int cmd,
    int subcmd, [
    List<int> data = const [],
  ]) => [0, id, cmd, subcmd, ...data];
  static List<int> querySoftwareVersion() => frame(1, 0x11, 0);
  static List<int> queryHardwareVersion() => frame(2, 0x11, 1);
  static List<int> queryBattery() => frame(3, 0x12, 0);
  static List<int> queryCharging() => frame(4, 0x12, 1);
  static List<int> queryDeviceTime() => frame(5, 0x10, 1);
  static List<int> setDeviceTime() => frame(
    6,
    0x10,
    0,
    encodeUint64Le(DateTime.now().toUtc().millisecondsSinceEpoch),
  );

  /// 0x34/0x00 体温同步直读，不受测量互斥限制，可随时插队。
  static List<int> readTemperature() => frame(7, temperatureCommand, 0);

  /// 0x33/0x00 仅 HR，默认 30 s。
  static List<int> measureHr(int id) => frame(id, hrCommand, 0);

  /// 0x33/0x01 仅 HRV，默认 120 s。响应里的 hr 是 HRV 算法的输入，不是 HRV 值。
  static List<int> measureHrv(int id) => frame(id, hrCommand, 1);

  /// 0x32/0x00 血氧，默认 60 s。
  static List<int> measureSpo2(int id) => frame(id, spo2Command, 0);

  /// 0x38/0x00 停止当前测量，任何状态下都可发，空闲时回 0x00。
  static List<int> stopMeasure(int id) => frame(id, stopMeasureCommand, 0);

  /// 按测量项构造请求帧；省略数据段即使用固件默认时长。
  static List<int> measure(int id, MeasureKind kind) => switch (kind) {
    MeasureKind.temperature => readTemperature(),
    MeasureKind.hr => measureHr(id),
    MeasureKind.hrv => measureHrv(id),
    MeasureKind.spo2 => measureSpo2(id),
  };

  static List<int> historyCapacity(int id) => frame(id, localDataCommand, 4);
  static List<int> readHistory(int id, {required bool all}) =>
      frame(id, localDataCommand, all ? 1 : 0);
  static List<int> stopHistory(int id) => frame(id, localDataCommand, 2);

  static bool isMeasureCommand(int cmd) =>
      cmd == hrHrvCommand || cmd == spo2Command || cmd == hrCommand;

  /// 解析测量响应帧；缺字段时为 null，交由上层判定有效性。
  static MeasureResponse parseMeasure(List<int> bytes) {
    if (bytes.length < 5) throw const FormatException('测量响应帧长度不足');
    final cmd = bytes[2], sub = bytes[3], status = bytes[4];
    int? hr;
    int? hrv;
    int? spo2;
    if (cmd == hrCommand && sub == 0 && bytes.length >= 6) {
      hr = bytes[5];
    } else if (cmd == hrCommand && sub == 1 && bytes.length >= 7) {
      hr = bytes[5];
      hrv = bytes[6];
    } else if (cmd == hrHrvCommand && bytes.length >= 7) {
      hr = bytes[5];
      hrv = bytes[6];
    } else if (cmd == spo2Command && bytes.length >= 6) {
      spo2 = bytes[5];
    }
    return MeasureResponse(
      frameId: bytes[1],
      cmd: cmd,
      subcmd: sub,
      status: status,
      hr: hr,
      hrv: hrv,
      spo2: spo2,
    );
  }

  static String measureStatusLabel(int value) =>
      const {
        0x00: '未佩戴 / 测量中断',
        0x01: '结果帧',
        0x02: '充电中',
        0x03: '采集中',
        0x04: '繁忙',
      }[value] ??
      '0x${value.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// 0x38/0x00 响应 data[0]：本次被中止的是哪条测量链。
  static String stopMeasureLabel(int value) =>
      const {
        0x00: '空闲，本来就没有测量在跑',
        0x01: '已中止：仅 HR',
        0x02: '已中止：仅 HRV',
        0x03: '已中止：HR + HRV',
        0x04: '已中止：SpO2',
      }[value] ??
      '未知(0x${value.toRadixString(16).padLeft(2, '0').toUpperCase()})';

  static String hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  /// 8 字节小端 uint64（用于 epoch ms）。
  ///
  /// 不用 `ByteData.setUint64` / `getUint64`：这两个访问器在 dart2js 上会抛
  /// `Unsupported operation`，位运算 `<< >> &` 在 web 上也只作用于低 32 位。
  /// 这里统一用整除与取余，保证 VM 与 web 结果一致。
  static List<int> encodeUint64Le(int value) {
    final bytes = <int>[];
    var rest = value;
    for (var i = 0; i < 8; i++) {
      bytes.add(rest % 256);
      rest = rest ~/ 256;
    }
    return bytes;
  }

  static int decodeUint64Le(List<int> bytes, int offset) {
    var value = 0;
    for (var i = offset + 7; i >= offset; i--) {
      value = value * 256 + bytes[i];
    }
    return value;
  }

  static DateTime parseDeviceTime(List<int> bytes) {
    if (bytes.length < 12) throw const FormatException('设备时间帧长度不足');
    final ms = decodeUint64Le(bytes, 4);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  static String describe(List<int> bytes) {
    if (bytes.length < 4) return '无效帧: 长度不足';
    final cmd = bytes[2], sub = bytes[3];
    if (cmd == 0x11) {
      return '版本响应: ${String.fromCharCodes(bytes.sublist(4)).replaceAll('\x00', '')}';
    }
    if (cmd == 0x12 && bytes.length > 4) {
      return sub == 0
          ? '电量: ${bytes[4]}%'
          : '充电状态: ${bytes[4] == 0 ? '未充电' : '充电中'}';
    }
    if (cmd == 0x10 && sub == 1 && bytes.length >= 12) {
      final ms = decodeUint64Le(bytes, 4);
      return '设备时间: ${DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal()}';
    }
    if (cmd == temperatureCommand && bytes.length >= 7) {
      final raw = ByteData.sublistView(
        Uint8List.fromList(bytes),
      ).getInt16(5, Endian.little);
      return '体温: ${bytes[4] == 1 ? '${(raw / 100).toStringAsFixed(2)} °C' : '读取失败'}';
    }
    if (cmd == stopMeasureCommand && bytes.length > 4) {
      return '停止测量: ${stopMeasureLabel(bytes[4])}';
    }
    if (isMeasureCommand(cmd) && bytes.length >= 5) {
      try {
        final frame = parseMeasure(bytes);
        final status = measureStatusLabel(frame.status);
        final data = <String>[];
        if (frame.hr != null) data.add('HR=${frame.hr} bpm');
        if (frame.hrv != null) data.add('HRV=${frame.hrv} ms');
        if (frame.spo2 != null) data.add('SpO2=${frame.spo2} %');
        final suffix = data.isEmpty ? '' : '  ${data.join('  ')}';
        return '测量响应(${_measureCommandName(cmd, frame.subcmd)}) $status$suffix';
      } on FormatException {
        // 只带状态位、缺数据位的畸形帧：退回原始 hex，不能让日志抛异常。
        return '响应帧 ${hex(bytes)}';
      }
    }
    if (cmd == localDataCommand) {
      return '历史数据响应: ${historyStatus(bytes.length > 4 ? bytes[4] : -1)}';
    }
    return '响应帧 ${hex(bytes)}';
  }

  static String _measureCommandName(int cmd, int subcmd) {
    if (cmd == hrHrvCommand) return 'HR + HRV';
    if (cmd == spo2Command) return 'SpO2';
    if (cmd == hrCommand) return subcmd == 1 ? 'HRV' : 'HR';
    return hex([cmd, subcmd]);
  }

  static TempHistoryCapacity parseCapacity(List<int> bytes) {
    if (bytes.length < 13) throw const FormatException('历史容量帧长度不足');
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return TempHistoryCapacity(
      status: bytes[4],
      count: data.getUint32(5, Endian.little),
      fileSize: data.getUint32(9, Endian.little),
    );
  }

  static TempHistoryPacket parsePacket(List<int> bytes) {
    if (bytes.length < 9) throw const FormatException('历史分包长度不足');
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final count = bytes[8];
    if (bytes.length < 9 + count * 15) throw const FormatException('历史记录不完整');
    final records = <TempHistoryRecord>[];
    for (var i = 0; i < count; i++) {
      final offset = 9 + i * 15;
      records.add(
        TempHistoryRecord(
          seq: data.getUint32(offset, Endian.little),
          unixMs: decodeUint64Le(bytes, offset + 4),
          temperatureX100: data.getInt16(offset + 12, Endian.little),
          valid: bytes[offset + 14] & 1 != 0,
        ),
      );
    }
    return TempHistoryPacket(
      frameId: bytes[1],
      status: bytes[4],
      flags: bytes[5],
      packetIndex: data.getUint16(6, Endian.little),
      records: records,
    );
  }

  static String historyStatus(int value) =>
      const {0: 'OK', 1: '忙', 2: '不支持', 3: '读取失败', 4: 'MTU 太小'}[value] ??
      '0x${value.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}
