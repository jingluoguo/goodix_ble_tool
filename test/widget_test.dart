import 'package:flutter_test/flutter_test.dart';

import 'package:goodix_ble_tool/models/ble_models.dart';
import 'package:goodix_ble_tool/services/gus_protocol.dart';

void main() {
  test('GUS frame builders use the documented payload format', () {
    expect(GusProtocol.hex(GusProtocol.queryBattery()), '00 03 12 00');
    expect(
      GusProtocol.hex(GusProtocol.readHistory(0x21, all: true)),
      '00 21 36 01',
    );
  });

  test('measurement frames omit the data segment to use firmware defaults', () {
    expect(
      GusProtocol.hex(GusProtocol.measure(0x31, MeasureKind.hr)),
      '00 31 33 00',
    );
    expect(
      GusProtocol.hex(GusProtocol.measure(0x31, MeasureKind.hrv)),
      '00 31 33 01',
    );
    expect(
      GusProtocol.hex(GusProtocol.measure(0x31, MeasureKind.spo2)),
      '00 31 32 00',
    );
    expect(
      GusProtocol.hex(GusProtocol.measure(0x31, MeasureKind.temperature)),
      '00 07 34 00',
    );
    expect(GusProtocol.hex(GusProtocol.stopMeasure(0x31)), '00 31 38 00');
  });

  test('measurement responses split acceptance frames from result frames', () {
    final accepted = GusProtocol.parseMeasure([
      0x00,
      0x01,
      0x33,
      0x00,
      0x03,
      0x00,
    ]);
    expect(accepted.accepted, isTrue);
    expect(accepted.isResult, isFalse);
    expect(accepted.hr, 0);

    final result = GusProtocol.parseMeasure([
      0x00,
      0x01,
      0x33,
      0x00,
      0x01,
      0x4D,
    ]);
    expect(result.isResult, isTrue);
    expect(result.hr, 77);

    final hrv = GusProtocol.parseMeasure([
      0x00,
      0x01,
      0x33,
      0x01,
      0x01,
      0x4D,
      0x1F,
    ]);
    expect(hrv.hr, 77);
    expect(hrv.hrv, 31);

    final spo2 = GusProtocol.parseMeasure([0x00, 0x01, 0x32, 0x00, 0x01, 0x62]);
    expect(spo2.spo2, 98);

    expect(GusProtocol.stopMeasureLabel(0x02), '已中止：仅 HRV');
  });

  test('describe degrades gracefully on truncated frames', () {
    // _onNotify 允许的最小长度就是 4 字节，describe 不能在这里抛异常。
    expect(GusProtocol.describe([0x00, 0x01, 0x33, 0x00]), '响应帧 00 01 33 00');
    expect(GusProtocol.describe([0x00, 0x01, 0x38, 0x00]), '响应帧 00 01 38 00');
    expect(GusProtocol.describe([0x00, 0x01, 0x33]), '无效帧: 长度不足');
    // 只有状态位、缺数据位
    expect(
      GusProtocol.describe([0x00, 0x01, 0x33, 0x00, 0x01]),
      '测量响应(HR) 结果帧',
    );
  });

  test('history packets parse little-endian temperature records', () {
    final packet = <int>[
      0x00,
      0x21,
      0x36,
      0x01,
      0x00,
      0x03,
      0x00,
      0x00,
      0x01,
      0x2A,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x45,
      0x0E,
      0x01,
    ];
    final result = GusProtocol.parsePacket(packet);
    expect(result.first, isTrue);
    expect(result.last, isTrue);
    expect(result.records.single.seq, 42);
    expect(result.records.single.celsius, 36.53);
  });
}
