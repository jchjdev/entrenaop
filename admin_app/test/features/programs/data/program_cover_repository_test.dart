import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:entrenaop_admin/features/programs/data/program_cover_repository.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scenario in ['save', 'partial', 'conflict', 'remove', 'focus']) {
    test('Storage y RPC: $scenario', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'test-public-key',
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      final uploaded = <String>[];
      final cleaned = <String>[];
      Map<String, dynamic>? parameters;
      server.listen((request) async {
        final body = await request.fold<List<int>>([], (a, b) => a..addAll(b));
        Object response = {};
        final path = request.uri.path;
        if (path.contains('/storage/v1/object/') && request.method == 'POST') {
          final object = path.split('/program-covers-public/').last;
          uploaded.add(object);
          expect(request.headers.value('x-upsert'), 'false');
          expect(utf8.decode(body, allowMalformed: true), contains('31536000'));
          if (scenario == 'partial' && object.endsWith('/header.jpg')) {
            request.response.statusCode = 500;
            response = {
              'statusCode': '500',
              'error': 'Upload failed',
              'message': 'Upload failed',
            };
          } else {
            response = {'Key': object};
          }
        } else if (path.contains('/rpc/')) {
          expect(path, endsWith('/set_admin_program_cover_v2'));
          parameters = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          if (scenario == 'conflict') {
            request.response.statusCode = 409;
            response = {
              'code': '40001',
              'message': 'Conflict',
              'details': null,
              'hint': null,
            };
          } else {
            response = {
              'cover': {
                'program_id': 'fas',
                'card_image_path': parameters!['p_card_image_path'],
                'header_image_path': parameters!['p_header_image_path'],
                'focal_x': parameters!['p_focal_x'],
                'focal_y': parameters!['p_focal_y'],
                'header_focal_x': parameters!['p_header_focal_x'],
                'header_focal_y': parameters!['p_header_focal_y'],
                'revision': 3,
              },
              'previous_card_path': 'old/card.jpg',
              'previous_header_path': 'old/header.jpg',
            };
          }
        } else if (request.method == 'DELETE') {
          final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          cleaned.addAll((payload['prefixes'] as List).cast<String>());
          response = [];
        } else {
          request.response.statusCode = 404;
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final repository = SupabaseProgramCoverRepository(client);
      const current = ProgramCover(
        programId: 'fas',
        cardPath: 'old/card.jpg',
        headerPath: 'old/header.jpg',
        revision: 2,
      );
      final operation = repository.save(
        current,
        focalX: 0.8,
        focalY: 0.2,
        headerFocalX: 0.6,
        headerFocalY: 0.7,
        removeImage: scenario == 'remove',
        upload: ['focus', 'remove'].contains(scenario)
            ? null
            : ProgramCoverUpload(
                card: Uint8List.fromList([1, 2, 3]),
                header: Uint8List.fromList([4, 5, 6]),
              ),
      );
      if (scenario == 'partial') {
        await expectLater(operation, throwsA(isA<StorageException>()));
        expect(parameters, isNull);
        expect(cleaned, [uploaded.first]);
      } else if (scenario == 'conflict') {
        await expectLater(operation, throwsA(isA<ProgramCoverConflict>()));
        expect(cleaned, uploaded);
        expect(cleaned, isNot(contains('old/card.jpg')));
      } else {
        final saved = await operation;
        expect(parameters!['p_expected_revision'], 2);
        expect(parameters!['p_program_id'], 'fas');
        expect(saved.revision, 3);
        expect(saved.focalX, 0.8);
        expect(parameters!['p_header_focal_x'], 0.6);
        expect(parameters!['p_header_focal_y'], 0.7);
        expect(saved.headerFocalX, 0.6);
        expect(saved.headerFocalY, 0.7);
        if (scenario == 'focus') {
          expect(uploaded, isEmpty);
          expect(cleaned, isEmpty);
          expect(parameters!['p_card_image_path'], current.cardPath);
        } else {
          expect(cleaned, ['old/card.jpg', 'old/header.jpg']);
          if (scenario == 'remove') {
            expect(uploaded, isEmpty);
            expect(saved.hasImage, isFalse);
          } else {
            expect(
              uploaded.first,
              matches(r'^official/fas/[a-f0-9]{32}/card.jpg$'),
            );
            expect(
              saved.cardUrl,
              contains(
                '/storage/v1/object/public/program-covers-public/official/fas/',
              ),
            );
          }
        }
      }
    });
  }
}
