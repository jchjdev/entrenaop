import 'dart:convert';
import 'dart:io';

import 'package:entrenaop_admin/features/editorial_covers/data/program_cover_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'el editor de una revisión carga la portada y revisión de la familia',
    () async {
      const family = '00000000-0000-4000-8000-000000000001';
      const version = '00000000-0000-4000-8000-000000000002';
      final requests = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'fixture',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      server.listen((request) async {
        requests.add(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            request.uri.path.endsWith('/guided_programs')
                ? {'family_id': family}
                : [
                    {
                      'program_id': family,
                      'revision': 4,
                      'card_image_path': 'guided/$family/card.jpg',
                      'header_image_path': 'guided/$family/header.jpg',
                      'focal_x': 0.8,
                      'focal_y': 0.2,
                      'header_focal_x': 0.3,
                      'header_focal_y': 0.7,
                    },
                  ],
          ),
        );
        await request.response.close();
      });
      final cover = await SupabaseProgramCoverRepository(
        client,
        resource: ProgramCoverResource.guided,
      ).load(version);
      expect(requests.first.queryParameters['id'], 'eq.$version');
      expect(requests.last.queryParameters['program_id'], 'eq.$family');
      expect(cover.programId, family);
      expect(cover.revision, 4);
      expect(cover.cardUrl, contains('guided/$family/card.jpg'));
      expect(cover.focalX, 0.8);
      expect(cover.headerFocalY, 0.7);
    },
  );
}
