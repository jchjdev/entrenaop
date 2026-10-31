import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:entrenaop_trainer/trainer_client_card.dart';

void main() {
  testWidgets(
    'la ficha muestra la foto autorizada y vuelve a iniciales al retirarla',
    (tester) async {
      var downloads = 0;
      final row = <String, dynamic>{
        'person_id': 'pupil',
        'person_name': 'Ana Alumna',
        'is_self': false,
        'created_at': '2026-10-31T00:00:00Z',
        'updated_at': '2026-10-31T00:00:00Z',
        'accepted_at': '2026-10-31T00:00:00Z',
        'active_relation_id': 'relation',
        'episode_count': 1,
        'profile_photo_path': 'pupil/photo.jpg',
      };
      Widget card() => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: TrainerClientCard(
                client: TrainerClient.fromJson(row),
                busy: false,
                techniqueMode: true,
                onManage: (_) {},
                photoLoader: (path) async {
                  expect(path, 'pupil/photo.jpg');
                  downloads++;
                  return base64Decode(
                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a22kAAAAASUVORK5CYII=',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();
      expect(downloads, 1);
      expect(find.byType(Image), findsOneWidget);
      row['profile_photo_path'] = null;
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();
      expect(downloads, 1);
      expect(find.text('AA'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
}
