import '../models/ble_models.dart';

class LogExportService {
  const LogExportService();

  /// [entries] 按控制器里的顺序传入（最新在前）。
  String buildText({
    required String deviceName,
    required String deviceId,
    required List<BleLogEntry> entries,
  }) {
    final buffer = StringBuffer()
      ..writeln('Goodix GUS 联调日志')
      ..writeln('设备: $deviceName')
      ..writeln('设备 ID: $deviceId')
      ..writeln('导出时间: ${DateTime.now().toLocal().toIso8601String()}')
      ..writeln('日志条数: ${entries.length}')
      ..writeln()
      ..writeln('时间\t方向\t内容');

    for (final entry in entries) {
      buffer.writeln(
        '${entry.time.toIso8601String()}\t${entry.direction}\t'
        '${entry.isError ? '[错误] ' : ''}${entry.message}',
      );
    }
    return buffer.toString();
  }
}
