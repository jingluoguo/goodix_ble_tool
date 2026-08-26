import 'gus_protocol.dart';

class HistoryExportService {
  const HistoryExportService();

  String buildText({
    required String deviceName,
    required String deviceId,
    required List<TempHistoryRecord> records,
  }) {
    final buffer = StringBuffer()
      ..writeln('Goodix GUS 温度历史')
      ..writeln('设备: $deviceName')
      ..writeln('设备 ID: $deviceId')
      ..writeln('导出时间: ${DateTime.now().toLocal().toIso8601String()}')
      ..writeln('记录数: ${records.length}')
      ..writeln()
      ..writeln('序号\t设备时间\t温度(°C)\t状态');

    for (final record in records) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        record.unixMs,
        isUtc: true,
      ).toLocal();
      buffer.writeln(
        '${record.seq}\t${time.toIso8601String()}\t'
        '${record.valid ? record.celsius!.toStringAsFixed(2) : '--'}\t'
        '${record.valid ? '有效' : '无效'}',
      );
    }
    return buffer.toString();
  }
}
