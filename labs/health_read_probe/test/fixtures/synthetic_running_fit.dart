import 'dart:typed_data';

/// Binario sintético construido desde campos FIT; no usa el códec bajo prueba.
Uint8List syntheticRunningFit({
  int manufacturer = 1,
  Endian endian = Endian.little,
  int sport = 1,
  int sessions = 1,
  bool metrics = true,
  bool lap = true,
  int lapCount = 1,
  int lapTrigger = 2,
  int? lapEnd,
  bool headerCrc = false,
  int? distanceRaw,
}) {
  final records = <int>[];
  void message(int local, int global, List<(int, int, int, int)> fields) {
    final definition = ByteData(2)..setUint16(0, global, endian);
    records.addAll([
      0x40 | local,
      0,
      endian == Endian.little ? 0 : 1,
      ...definition.buffer.asUint8List(),
      fields.length,
      for (final field in fields) ...[field.$1, field.$2, field.$3],
      local,
    ]);
    for (final field in fields) {
      final data = ByteData(field.$2);
      switch (field.$2) {
        case 1:
          data.setUint8(0, field.$4);
        case 2:
          data.setUint16(0, field.$4, endian);
        case 4:
          data.setUint32(0, field.$4, endian);
      }
      records.addAll(data.buffer.asUint8List());
    }
  }

  message(0, 0, [(0, 1, 0, 4), (1, 2, 0x84, manufacturer)]);
  for (var i = 0; i < sessions; i++) {
    message(1, 18, [
      (253, 4, 0x86, 1000001801),
      (2, 4, 0x86, 1000000000),
      (5, 1, 0, sport),
      if (metrics) ...[
        (7, 4, 0x86, 1800123),
        (8, 4, 0x86, 1700456),
        (9, 4, 0x86, distanceRaw ?? 500012),
        (16, 1, 2, 143),
        (17, 1, 2, 181),
      ],
    ]);
  }
  for (var index = 0; index < (lap ? lapCount : 0); index++) {
    message(2, 19, [
      (253, 4, 0x86, lapEnd ?? 1000000600),
      (2, 4, 0x86, 1000000000),
      (7, 4, 0x86, 600000),
      (8, 4, 0x86, 590125),
      (9, 4, 0x86, 100001),
      (24, 1, 0, lapTrigger),
    ]);
  }
  return wrapSyntheticFit(records, headerCrc: headerCrc);
}

Uint8List wrapSyntheticFit(List<int> records, {bool headerCrc = false}) {
  final header = ByteData(12)
    ..setUint8(0, headerCrc ? 14 : 12)
    ..setUint8(1, 0x20)
    ..setUint16(2, 2160, Endian.little)
    ..setUint32(4, records.length, Endian.little);
  final bytes = <int>[...header.buffer.asUint8List()];
  bytes.setRange(8, 12, [0x2e, 0x46, 0x49, 0x54]);
  if (headerCrc) {
    final crc = syntheticCrc(bytes);
    bytes.addAll([crc & 255, crc >> 8]);
  }
  bytes.addAll(records);
  final crc = syntheticCrc(bytes);
  return Uint8List.fromList([...bytes, crc & 255, crc >> 8]);
}

// CRC-16/ARC: implementación bit a bit independiente de la tabla del códec.
int syntheticCrc(List<int> bytes) {
  var crc = 0;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 == 1 ? (crc >> 1) ^ 0xa001 : crc >> 1;
    }
  }
  return crc;
}
