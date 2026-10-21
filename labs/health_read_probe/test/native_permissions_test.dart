import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android health permissions remain limited to reading exercise sessions',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final healthPermissions = RegExp(
        r'<uses-permission\s+android:name="([^"]+)"',
      ).allMatches(manifest).map((match) => match[1]);
      expect(healthPermissions, ['android.permission.health.READ_EXERCISE']);
      expect(
        manifest,
        contains('android.permission.START_VIEW_PERMISSION_USAGE'),
      );
      expect(manifest, contains('android.intent.category.HEALTH_PERMISSIONS'));
      final kotlin = File(
        'android/app/src/main/kotlin/es/entrenaop/health_read_probe/RunningHealthReader.kt',
      ).readAsStringSync();
      expect(kotlin, isNot(contains('client.aggregate(')));
      expect(kotlin, isNot(contains('client.insertRecords(')));
    },
  );
  test('iOS declares HealthKit read access without background delivery or write rationale', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlement = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    expect(info, contains('NSHealthShareUsageDescription'));
    expect(info, isNot(contains('NSHealthUpdateUsageDescription')));
    expect(entitlement, contains('<key>com.apple.developer.healthkit</key>'));
    expect(entitlement, isNot(contains('background-delivery')));
    final swift = File(
      '../../packages/device_health/ios/device_health/Sources/device_health/DeviceHealthPlugin.swift',
    ).readAsStringSync();
    expect(swift, contains('toShare: [], read: [HKObjectType.workoutType()]'));
    expect(swift, isNot(contains('store.save(')));
  });
}
