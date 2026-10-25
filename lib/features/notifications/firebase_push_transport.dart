import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import 'push_notifications.dart';

/// Con auto-init apagado, FlutterFire 17 no pide la dirección APNs al arrancar.
/// Solo se habilita tras el consentimiento; esperar antes produciría un bloqueo
/// permanente en el primer registro de iPhone.
Future<void> prepareFirebasePushRegistration(
  FirebaseMessaging messaging, {
  required bool ios,
}) async {
  await messaging.setAutoInitEnabled(true);
  if (!ios) return;
  for (var attempt = 0; attempt < 40; attempt++) {
    if (await messaging.getAPNSToken() != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('APNs todavía no está disponible.');
}

/// Solo transporte. No utiliza Firebase Auth, base de datos ni Analytics.
class FirebasePushTransport implements PushTransport {
  @override
  bool lastOpenWasReminder = false;
  static const _enabled = bool.fromEnvironment('PUSH_ENABLED');
  static const _project = String.fromEnvironment('PUSH_FIREBASE_PROJECT_ID');
  static const _sender = String.fromEnvironment('PUSH_FIREBASE_SENDER_ID');
  static const _androidApp = String.fromEnvironment(
    'PUSH_FIREBASE_ANDROID_APP_ID',
  );
  static const _iosApp = String.fromEnvironment('PUSH_FIREBASE_IOS_APP_ID');
  static const _androidKey = String.fromEnvironment(
    'PUSH_FIREBASE_ANDROID_API_KEY',
  );
  static const _iosKey = String.fromEnvironment('PUSH_FIREBASE_IOS_API_KEY');
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  String get projectId => _project;
  String get _appId => platform == 'ios' ? _iosApp : _androidApp;
  String get _apiKey => platform == 'ios' ? _iosKey : _androidKey;
  @override
  bool get available =>
      _enabled &&
      !kIsWeb &&
      AppConfig.environment == AppEnvironment.development &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      [_project, _sender, _appId, _apiKey].every((s) => s.isNotEmpty);
  final _foreground = StreamController<void>.broadcast(),
      _opens = StreamController<void>.broadcast(),
      _tokens = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  FirebaseMessaging? _messaging;
  Future<void>? _initializing;
  Completer<String>? _registration;
  String? _fid;
  bool _registering = false;
  bool _disposed = false;
  @override
  Stream<void> get foregroundEvents => _foreground.stream;
  @override
  Stream<void> get openEvents => _opens.stream;
  @override
  Stream<void> get tokenEvents => _tokens.stream;
  bool _valid(RemoteMessage message) =>
      message.data['type'] == 'student_notices';
  @override
  Future<void> initialize() async {
    if (_disposed) throw StateError('Transporte cerrado.');
    if (!available) throw StateError('Transporte sin configurar.');
    if (_messaging != null) return;
    if (_initializing case final pending?) return pending;
    final pending = _initialize();
    _initializing = pending;
    try {
      await pending;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _sender,
              projectId: _project,
            ),
          )
        : Firebase.app();
    if (app.options.projectId != _project) {
      throw StateError('Proyecto de avisos incompatible.');
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(false);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    if (_disposed) throw StateError('Transporte cerrado.');
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((m) {
        if (_valid(m)) _foreground.add(null);
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        if (_valid(m)) {
          lastOpenWasReminder = m.data['notice_kind'] == 'reminder';
          _opens.add(null);
        }
      }),
    );
    _subscriptions.add(
      messaging.onRegistered.listen(
        (fid) {
          final changed = _fid != fid;
          _fid = fid;
          final pending = _registration;
          if (pending != null && !pending.isCompleted) pending.complete(fid);
          if (changed && !_registering) _tokens.add(null);
        },
        onError: (Object _) {
          // register() conserva su fallo/timeout; una renovación posterior o
          // volver a la app reintenta sin propagar errores del canal al usuario.
        },
      ),
    );
    _messaging = messaging;
    final initial = await messaging.getInitialMessage();
    if (initial != null && _valid(initial)) {
      lastOpenWasReminder = initial.data['notice_kind'] == 'reminder';
      _opens.add(null);
    }
  }

  @override
  Future<bool> permitted({bool request = false}) async {
    final messaging = _messaging!;
    final settings = request
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    final messaging = _messaging!;
    // FlutterFire 17 registra un FID. No utiliza las API antiguas de tokens.
    final result = Completer<String>();
    _registration = result;
    _registering = true;
    try {
      await prepareFirebasePushRegistration(messaging, ios: platform == 'ios');
      if (_disposed) throw StateError('Transporte cerrado.');
      await messaging.register().timeout(const Duration(seconds: 20));
      return await result.future.timeout(const Duration(seconds: 20));
    } finally {
      _registration = null;
      _registering = false;
    }
  }

  @override
  Future<void> deleteToken() async {
    final messaging = _messaging;
    if (messaging == null) return;
    await messaging.setAutoInitEnabled(false);
    await messaging.unregister();
    _fid = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final pending = _registration;
    if (pending != null && !pending.isCompleted) pending.complete('');
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _foreground.close();
    await _opens.close();
    await _tokens.close();
  }
}
