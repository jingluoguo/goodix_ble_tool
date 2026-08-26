import 'dart:typed_data';

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

class GusProtocol {
  static const serviceUuid = 'A6ED0201-D344-460A-8075-B9E8EC90D71B';
  static const txUuid = 'A6ED0202-D344-460A-8075-B9E8EC90D71B';
  static const rxUuid = 'A6ED0203-D344-460A-8075-B9E8EC90D71B';
  static const flowUuid = 'A6ED0204-D344-460A-8075-B9E8EC90D71B';
  static const localDataCommand = 0x36;

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
  static List<int> setDeviceTime() {
    final bytes = Uint8List(8);
    ByteData.view(bytes.buffer).setUint64(
      0,
      DateTime.now().toUtc().millisecondsSinceEpoch,
      Endian.little,
    );
    return frame(6, 0x10, 0, bytes.toList());
  }

  static List<int> startTemperature() => frame(7, 0x34, 0);
  static List<int> historyCapacity(int id) => frame(id, localDataCommand, 4);
  static List<int> readHistory(int id, {required bool all}) =>
      frame(id, localDataCommand, all ? 1 : 0);
  static List<int> stopHistory(int id) => frame(id, localDataCommand, 2);

  static String hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  static DateTime parseDeviceTime(List<int> bytes) {
    if (bytes.length < 12) throw const FormatException('设备时间帧长度不足');
    final ms = ByteData.sublistView(
      Uint8List.fromList(bytes),
    ).getUint64(4, Endian.little);
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
      final ms = ByteData.sublistView(
        Uint8List.fromList(bytes),
      ).getUint64(4, Endian.little);
      return '设备时间: ${DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal()}';
    }
    if (cmd == 0x34 && bytes.length >= 7) {
      final raw = ByteData.sublistView(
        Uint8List.fromList(bytes),
      ).getInt16(5, Endian.little);
      return '实时温度: ${bytes[4] == 1 ? '${(raw / 100).toStringAsFixed(2)} °C' : '无效'}';
    }
    if (cmd == localDataCommand) {
      return '历史数据响应: ${historyStatus(bytes.length > 4 ? bytes[4] : -1)}';
    }
    return '响应帧 ${hex(bytes)}';
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
          unixMs: data.getUint64(offset + 4, Endian.little),
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
