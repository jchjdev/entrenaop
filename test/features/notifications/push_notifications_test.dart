import 'dart:async';

import 'package:entrenaop/features/notifications/notice_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entrenaop/features/notifications/push_notifications.dart';
import 'package:entrenaop/features/notifications/push_data.dart';
import 'package:entrenaop/features/notifications/firebase_push_transport.dart';

class Transport implements PushTransport {
  @override
  bool lastOpenWasReminder = false;
  @override
  bool available = true;
  @override
  String projectId = 'push-fixture';
  @override
  String platform = 'ios';
  final foreground = StreamController<void>.broadcast(),
      open = StreamController<void>.broadcast(),
      tokens = StreamController<void>.broadcast();
  bool allowed = true;
  int initializations = 0, requests = 0, deletions = 0;
  Completer<String?>? pending;
  final requested = Completer<void>();
  @override
  Stream<void> get foregroundEvents => foreground.stream;
  @override
  Stream<void> get openEvents => open.stream;
  @override
  Stream<void> get tokenEvents => tokens.stream;
  @override
  Future<void> initialize() async {
    initializations++;
  }

  @override
  Future<bool> permitted({bool request = false}) async {
    if (request) requests++;
    return allowed;
  }

  @override
  Future<String?> token() async {
    if (!requested.isCompleted) requested.complete();
    return pending?.future ?? 'current-fid';
  }

  @override
  Future<void> deleteToken() async {
    deletions++;
  }

  @override
  Future<void> dispose() async {
    await foreground.close();
    await open.close();
    await tokens.close();
  }
}

class Store implements PushStore {
  final choices = <String, bool>{};
  @override
  Future<PushInstallation> installation() async =>
      const PushInstallation('installation', 'secret');
  @override
  Future<bool> optedIn(String owner) async => choices[owner] ?? false;
  @override
  Future<void> setOptedIn(String owner, bool enabled) async {
    choices[owner] = enabled;
  }
}

class Backend implements PushBackend {
  Completer<NoticePreferences>? pendingPreferences;
  DateTime? reminder;
  Completer<DateTime?>? pendingReminder;
  @override
  Future<NoticePreferences> savePreferences(
    PushAccount account,
    NoticePreferences value,
  ) async =>
      pendingPreferences?.future ??
      value.copyWith(revision: value.revision + 1);
  @override
  Future<List<String>> timezones(PushAccount account) async => [
    'UTC',
    'Europe/Madrid',
  ];
  @override
  Future<DateTime?> reminderDate(PushAccount account) async =>
      pendingReminder?.future ?? reminder;

  PushConfiguration config = const PushConfiguration(true, 'push-fixture');
  String? owner, binding;
  bool loseResponse = false;
  final registrations = <String>[], revoked = <String>[];
  @override
  Future<PushConfiguration> configuration(PushAccount account) async => config;
  @override
  Future<PushDeviceState?> device(
    PushAccount account,
    PushInstallation installation,
  ) async =>
      binding == null ? null : PushDeviceState(binding!, owner == account.id);
  @override
  Future<void> register(
    PushAccount account,
    PushInstallation installation, {
    required String bindingId,
    required String? previousBinding,
    required String token,
    required String platform,
  }) async {
    registrations.add(account.id);
    owner = account.id;
    binding = bindingId;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Respuesta perdida tras confirmar');
    }
  }

  @override
  Future<void> revoke(
    PushAccount account,
    PushInstallation installation,
  ) async {
    if (owner == account.id) {
      revoked.add(account.id);
      owner = null;
      binding = null;
    }
  }
}

class Fixture {
  final transport = Transport(), store = Store(), backend = Backend();
  int sequence = 0;
  late final coordinator = PushNotificationCoordinator(
    transport: transport,
    backend: backend,
    store: store,
    newId: () => 'binding-${++sequence}',
  );
}

const a = PushAccount('A', 'bearer-A'), b = PushAccount('B', 'bearer-B');

void main() {
  test(
    'guarda preferencias por cuenta y descarta una respuesta tardía de A',
    () async {
      final f = Fixture();
      addTearDown(f.coordinator.dispose);
      await f.coordinator.setAccount(a);
      expect(f.coordinator.preferences.reminderMode, 'off');
      f.backend.pendingPreferences = Completer<NoticePreferences>();
      final save = f.coordinator.savePreferences(
        const NoticePreferences(
          reminderMode: 'previousDay',
          reminderMinute: 1080,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final change = f.coordinator.setAccount(b);
      f.backend.pendingPreferences!.complete(
        const NoticePreferences(revision: 1, reminderMode: 'previousDay'),
      );
      await save;
      await change;
      expect(f.coordinator.accountId, b.id);
      expect(f.coordinator.preferences.reminderMode, 'off');
      expect(f.coordinator.preferences.revision, 0);
      f.backend.pendingPreferences = null;
      await f.coordinator.savePreferences(
        const NoticePreferences(reminderMode: 'sameDay', reminderMinute: 600),
      );
      expect(f.coordinator.preferences.reminderMode, 'sameDay');
      expect(f.coordinator.preferences.revision, 1);
    },
  );
  test('abre la fecha propia del recordatorio y rechaza el resultado tras cambiar de cuenta', () async {
    final f = Fixture();
    addTearDown(f.coordinator.dispose);
    await f.coordinator.setAccount(a);
    f.transport.lastOpenWasReminder = true;
    f.transport.open.add(null);
    await Future<void>.delayed(Duration.zero);
    f.backend.reminder = DateTime(2026, 10, 26);
    expect(await f.coordinator.routeForOpen(), '/plan/week?date=2026-10-26');
    f.backend.pendingReminder = Completer<DateTime?>();
    final route = f.coordinator.routeForOpen();
    await f.coordinator.setAccount(b);
    f.backend.pendingReminder!.complete(DateTime(2026, 10, 26));
    expect(await route, isNull);
  });

  test('configuración ausente no inicializa SDK ni pide permisos', () async {
    final f = Fixture()..transport.available = false;
    addTearDown(f.coordinator.dispose);
    await f.coordinator.setAccount(a);
    await f.coordinator.enable();
    expect(f.transport.initializations, 0);
    expect(f.transport.requests, 0);
    expect(f.backend.registrations, isEmpty);
    expect(FirebasePushTransport().available, false);
  });
  test(
    'servidor apagado o proyecto distinto no pide permiso ni registra',
    () async {
      for (final config in [
        const PushConfiguration(false, null),
        const PushConfiguration(true, 'other-project'),
      ]) {
        final f = Fixture()..backend.config = config;
        addTearDown(f.coordinator.dispose);
        await f.coordinator.setAccount(a);
        await f.coordinator.enable();
        expect(f.transport.requests, 0);
        expect(f.coordinator.serverAvailable, false);
        expect(f.backend.registrations, isEmpty);
      }
    },
  );
  test('permiso del teléfono no sustituye consentimiento por cuenta', () async {
    final f = Fixture();
    addTearDown(f.coordinator.dispose);
    await f.coordinator.setAccount(a);
    expect(f.backend.registrations, isEmpty);
    await f.coordinator.enable();
    expect(f.backend.registrations, ['A']);
    expect(f.coordinator.enabled, true);
    await f.coordinator.setAccount(b);
    expect(f.backend.registrations, ['A']);
    expect(f.store.choices['B'], isNull);
    expect(f.backend.revoked, ['A']);
    expect(f.coordinator.enabled, false);
  });
  test('cambio A→B mientras se obtiene dirección no registra A ni reutiliza su intención', () async {
    final f = Fixture();
    f.store.choices.addAll({'A': true, 'B': true});
    final gate = Completer<String?>();
    f.transport.pending = gate;
    addTearDown(f.coordinator.dispose);
    final first = f.coordinator.setAccount(a);
    await f.transport.requested.future;
    final next = f.coordinator.setAccount(b);
    f.transport.pending = null;
    gate.complete('old-fid');
    await Future.wait([first, next]);
    expect(f.backend.registrations, ['B']);
    expect(f.backend.owner, 'B');
  });
  test(
    'respuesta perdida puede desactivarse sin registrar una segunda vez',
    () async {
      final f = Fixture();
      addTearDown(f.coordinator.dispose);
      await f.coordinator.setAccount(a);
      f.backend.loseResponse = true;
      await f.coordinator.enable();
      expect(f.coordinator.error, isNotNull);
      expect(f.backend.owner, 'A');
      await f.coordinator.disable();
      expect(f.backend.registrations, ['A']);
      expect(f.backend.owner, isNull);
      expect(f.store.choices['A'], false);
    },
  );
  test('denegar permiso no registra y conserva elección individual', () async {
    final f = Fixture()..transport.allowed = false;
    addTearDown(f.coordinator.dispose);
    await f.coordinator.setAccount(a);
    await f.coordinator.enable();
    expect(f.transport.requests, 1);
    expect(f.coordinator.denied, true);
    expect(f.backend.registrations, isEmpty);
    expect(f.store.choices['A'], isNull);
  });
  test('avisos en primer plano se aíslan al cerrar la sesión', () async {
    final f = Fixture();
    f.store.choices['A'] = true;
    addTearDown(f.coordinator.dispose);
    var notices = 0;
    final subscription = f.coordinator.notices.listen((_) => notices++);
    addTearDown(subscription.cancel);
    await f.coordinator.setAccount(a);
    f.transport.foreground.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(notices, 1);
    await f.coordinator.setAccount(null);
    f.transport.foreground.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(notices, 1);
  });
  test(
    'pulsar aviso estando desconectado espera una sesión y no marca leído',
    () async {
      final f = Fixture();
      addTearDown(f.coordinator.dispose);
      var opens = 0;
      final subscription = f.coordinator.opens.listen((_) => opens++);
      addTearDown(subscription.cancel);
      await f.coordinator.setAccount(null);
      f.transport.open.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(opens, 0);
      await f.coordinator.setAccount(b);
      await Future<void>.delayed(Duration.zero);
      expect(opens, 1);
      expect(f.backend.registrations, isEmpty);
    },
  );
  test(
    'instalación local es estable y preferencias A/B permanecen separadas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalPushStore(), other = LocalPushStore();
      final installation = await store.installation(),
          again = await other.installation();
      expect(installation.id, again.id);
      expect(installation.secret, again.secret);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(installation.secret), true);
      await store.setOptedIn('A', true);
      expect(await other.optedIn('A'), true);
      expect(await other.optedIn('B'), false);
    },
  );
}
