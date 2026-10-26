import 'package:entrenaop/features/device_connections/domain/ciq_connection.dart';
import 'package:entrenaop/features/device_connections/data/supabase_ciq_connection_repository.dart';
import 'package:entrenaop/features/device_connections/presentation/ciq_connection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCiq implements CiqConnectionRepository {
  bool allowed = true;
  int approvals = 0, revokes = 0;
  String? reviewCode;
  @override
  Future<CiqAccount> load() async => CiqAccount(
    allowed,
    revokes > 0
        ? []
        : [
            CiqLink(
              'link',
              DateTime.utc(2026, 10, 26),
              DateTime.utc(2027),
              false,
              null,
            ),
          ],
  );
  @override
  Future<CiqPairReview> review(String code) async {
    reviewCode = code;
    return CiqPairReview('pair', 'fēnix de prueba', DateTime.utc(2027));
  }

  @override
  Future<void> approve(String code, String id) async {
    expect(code, reviewCode);
    expect(id, 'pair');
    approvals++;
  }

  @override
  Future<void> revoke(String id) async {
    expect(id, 'link');
    revokes++;
  }
}

void main() {
  testWidgets(
    'introducir código no vincula; exige revisión y confirmación explícita',
    (tester) async {
      final repository = FakeCiq();
      await tester.pumpWidget(
        MaterialApp(
          home: CiqConnectionPage(
            repository: repository,
            accountLabel: 'cuenta@fixture.invalid',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABCD-EF23');
      await tester.pump();
      await tester.tap(find.text('Revisar vinculación'));
      await tester.pumpAndSettle();
      expect(repository.approvals, 0);
      expect(find.text('fēnix de prueba'), findsOneWidget);
      await tester.ensureVisible(find.text('Vincular este reloj'));
      await tester.tap(find.text('Vincular este reloj'));
      await tester.pumpAndSettle();
      expect(repository.approvals, 1);
      expect(find.textContaining('Reloj vinculado.'), findsOneWidget);
    },
  );
  testWidgets('editar el código invalida la revisión anterior', (tester) async {
    final repository = FakeCiq();
    await tester.pumpWidget(
      MaterialApp(
        home: CiqConnectionPage(
          repository: repository,
          accountLabel: 'Fixture',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ABCD-EF23');
    await tester.pump();
    await tester.tap(find.text('Revisar vinculación'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'OTRO-2345');
    await tester.pump();
    expect(find.text('Vincular este reloj'), findsNothing);
    expect(repository.approvals, 0);
  });
  testWidgets('perder acceso comercial permite revocar pero impide vincular', (
    tester,
  ) async {
    final repository = FakeCiq()..allowed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CiqConnectionPage(
          repository: repository,
          accountLabel: 'Fixture',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('no puedes vincular, descargar ni sincronizar'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retirar acceso'));
    await tester.pumpAndSettle();
    expect(repository.revokes, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Retirar acceso'));
    await tester.pumpAndSettle();
    expect(repository.revokes, 1);
  });
  test(
    'el contrato de cuenta no acepta respuestas parciales o estado inventado',
    () {
      expect(
        () => decodeCiqAccount({
          'allowed': true,
          'links': [
            {'id': 'x'},
          ],
        }),
        throwsA(isA<CiqException>()),
      );
      expect(
        () => decodeCiqAccount({'links': []}),
        throwsA(isA<CiqException>()),
      );
      expect(decodeCiqAccount({'allowed': false, 'links': []}).allowed, false);
    },
  );
}
