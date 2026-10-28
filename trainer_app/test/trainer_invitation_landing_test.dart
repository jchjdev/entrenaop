import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop_trainer/trainer_invitation_landing.dart';
import 'package:trainer_access/trainer_invitation_link.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'página pública ofrece abrir, sin aceptar ni anunciar tiendas, texto $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Uri? opened;
        final code = List.filled(64, 'a').join();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: TrainerInvitationLanding(
                secret: code,
                open: (uri) async {
                  opened = uri;
                  return false;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aceptar preparador'), findsNothing);
        expect(find.textContaining('App Store'), findsNothing);
        if (find.text('Abrir EntrenaOP').evaluate().isEmpty) {
          await tester.scrollUntilVisible(find.text('Abrir EntrenaOP'), 250);
        }
        await tester.ensureVisible(find.text('Abrir EntrenaOP'));
        await tester.tap(find.text('Abrir EntrenaOP'));
        await tester.pumpAndSettle();
        expect(TrainerInvitationLink.parse(opened!), code);
        if (find
            .textContaining('No se pudo abrir EntrenaOP')
            .evaluate()
            .isEmpty) {
          await tester.scrollUntilVisible(
            find.textContaining('No se pudo abrir EntrenaOP'),
            200,
          );
        }
        expect(
          find.textContaining('No se pudo abrir EntrenaOP'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'invitación inválida no intenta abrir ni muestra contenido recibido',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerInvitationLanding(
            secret: null,
            open: (_) async {
              opens++;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invitación incompleta'), findsOneWidget);
      expect(find.text('Abrir EntrenaOP'), findsNothing);
      expect(opens, 0);
    },
  );
}
