import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/auth/presentation/admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  setUp(() {
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());
  testWidgets(
    'acceso admin con marca, validación y visibilidad de contraseña',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: AdminLoginPage(client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EntrenaWordmark), findsOneWidget);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Introduce tu correo.'), findsOneWidget);
      expect(find.text('Introduce tu contraseña.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );
    },
  );

  testWidgets('acceso admin desplazable con ventana estrecha y teclado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: AdminLoginPage(client: client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Entrar').hitTestable(), findsOneWidget);
  });
}
