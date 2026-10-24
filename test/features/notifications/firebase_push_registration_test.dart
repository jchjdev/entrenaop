import 'package:entrenaop/features/notifications/firebase_push_transport.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class NativeMessaging extends Fake implements FirebaseMessaging {
  NativeMessaging({this.availableAfter = 1});
  final int availableAfter;
  bool autoInit = false;
  int apnsReads = 0;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async => autoInit = enabled;
  @override
  Future<String?> getAPNSToken() async {
    if (!autoInit) {
      throw StateError('APNs no se solicita con auto-init apagado');
    }
    return ++apnsReads >= availableAfter ? 'native-apns-address' : null;
  }
}

void main() {
  testWidgets('primer registro iPhone habilita APNs y espera su respuesta', (
    tester,
  ) async {
    final native = NativeMessaging(availableAfter: 3);
    var completed = false;
    final registration = prepareFirebasePushRegistration(
      native,
      ios: true,
    ).then((_) => completed = true);
    await tester.pump();
    expect(native.autoInit, true);
    expect(completed, false);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await registration;
    expect(native.apnsReads, 3);
    expect(completed, true);
  });

  testWidgets('APNs ausente termina y permite reintentar sin quedar colgado', (
    tester,
  ) async {
    final native = NativeMessaging(availableAfter: 999);
    final result = expectLater(
      prepareFirebasePushRegistration(native, ios: true),
      throwsStateError,
    );
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await result;
    expect(native.apnsReads, 40);
  });

  test('Android no consulta la dirección APNs', () async {
    final native = NativeMessaging();
    await prepareFirebasePushRegistration(native, ios: false);
    expect(native.autoInit, true);
    expect(native.apnsReads, 0);
  });
}
