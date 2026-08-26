import 'package:flutter_test/flutter_test.dart';

import 'package:goodix_ble_tool/services/gus_protocol.dart';

void main() {
  test('GUS frame builders use the documented payload format', () {
    expect(GusProtocol.hex(GusProtocol.queryBattery()), '00 03 12 00');
    expect(
      GusProtocol.hex(GusProtocol.readHistory(0x21, all: true)),
      '00 21 36 01',
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
