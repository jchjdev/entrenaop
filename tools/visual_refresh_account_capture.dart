// Capturas de widgets reales con cuentas ficticias; no envía correos ni claves.
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/account_auth_fixture.dart';
import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_refresh_account_capture.dart';
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    atlasTestWidgets('Cuenta $width $scale', (tester) async {
      tester.view.physicalSize = Size(width, width > 900 ? 900 : 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AccountAuthFixture();
      final auth = repo.cubit()..watchAuthState();
      final router = AppRouter(auth);
      addTearDown(repo.changes.close);
      addTearDown(auth.close);
      addTearDown(router.dispose);
      router.config.go('/forgot-password');
      await atlasPumpWidget(
        tester,
        BlocProvider.value(
          value: auth,
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router.config,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await atlasSettle(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        'persona@example.com',
      );
      await auth.requestPasswordReset('persona@example.com');
      await atlasSettle(tester);
      await auth.signUp(
        email: 'persona@example.com',
        password: 'clave-ficticia',
        fullName: 'Persona de ejemplo',
      );
      router.config.go('/confirm-email');
      await atlasSettle(tester);
      repo.recover();
      await atlasSettle(tester);
      repo.failUpdate = true;
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'clave-ficticia-nueva',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'clave-ficticia-nueva',
      );
      await auth.updateRecoveredPassword('clave-ficticia-nueva');
      await atlasSettle(tester);
      repo.failUpdate = false;
      await auth.updateRecoveredPassword('clave-ficticia-nueva');
      await atlasSettle(tester);
      repo.changes.addError(const AuthLinkException());
      await atlasSettle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
