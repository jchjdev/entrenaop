// Capturas de widgets reales con datos ficticios y sin conexión a Supabase.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

void main() {
  var fontsLoaded = false;
  for (final (name, width, scale) in [
    ('desktop', 1200.0, 1.0),
    ('mobile', 390.0, 1.0),
    ('mobile-text2x', 320.0, 2.0),
  ]) {
    testWidgets('clientes $name', (tester) async {
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          for (final (family, path) in [
            ('Roboto', 'C:/Windows/Fonts/arial.ttf'),
            (
              'MaterialIcons',
              'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ),
          ]) {
            final bytes = await File(path).readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
        });
        fontsLoaded = true;
      }
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeTrainerRepository()
        ..active = [
          trainerRelation('Lucía Fernández'),
          trainerRelation(
            'Alejandro Martín de la Torre',
            personId: 'person-b',
            id: 'relation-b',
          ),
        ];
      repo.current = TrainerAccess.fromJson({
        'trainer_id': 'a',
        'enabled': true,
        'effective': true,
        'client_limit': 3,
        'active_clients': 2,
        'revision': 1,
      });
      repo.invites = [
        TrainerInvitation.fromJson({
          'id': '12345678-1234-4000-8000-123456789abc',
          'created_at': '2026-10-21T07:00:00Z',
          'expires_at': '2030-01-01T00:00:00Z',
        }),
      ];
      const key = ValueKey('capture');
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: key, child: child!),
          ),
          home: TrainerClientsPage(repository: repo, onSignOut: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(
            'assets/branding/entrenaop_wordmark_on_dark.png',
            package: 'entrena_ui',
          ),
          tester.element(find.byType(TrainerClientsPage)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory('build/trainer-visual')
          ..createSync(recursive: true);
        File('${output.path}/$name.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
      if (scale > 1) {
        await tester.scrollUntilVisible(
          find.text('Desactivar servicio').first,
          300,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/trainer-visual/$name-clients.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
