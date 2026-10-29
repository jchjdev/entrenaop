import 'dart:convert';
import 'dart:typed_data';

import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';

import 'admin_exercise_preferences_repository_test.dart'
    show clientFor, owner, response;

void main() {
  final stamp = DateTime.utc(2026, 10, 29, 12, 30, 15, 123, 456);
  const operation = '30000000-0000-4000-8000-000000000001';
  const exerciseId = '20000000-0000-4000-8000-000000000001';

  for (final status in ['trashed', 'restored', 'purged']) {
    final valid = <String, Object?>{
      'id': exerciseId,
      'kind': 'exercise',
      'status': status,
      if (status == 'trashed') 'trashed_at': stamp.toIso8601String(),
    };
    final malformed = <(String, Object?)>[
      ('null', null),
      ('sin campos', <String, Object?>{}),
      ('tipo incorrecto', 'ok'),
      ('id ajeno', {...valid, 'id': 'different-exercise'}),
      ('catálogo incorrecto', {...valid, 'kind': 'program'}),
      ('estado incorrecto', {...valid, 'status': 'unknown'}),
      if (status == 'trashed') ...[
        ('sin sello', {...valid, 'trashed_at': null}),
        ('sello inválido', {...valid, 'trashed_at': 'no-es-fecha'}),
      ],
    ];
    for (final (label, badReceipt) in malformed) {
      test(
        '$status rechaza 200 con $label y permite confirmar el mismo UUID',
        () async {
          final calls = <Map<String, dynamic>>[];
          var confirmed = false;
          final client = clientFor((request) async {
            calls.add(
              Map<String, dynamic>.from(jsonDecode(request.body) as Map),
            );
            return http.Response(
              jsonEncode(confirmed ? valid : badReceipt),
              200,
              headers: {'content-type': 'application/json'},
            );
          });
          addTearDown(client.dispose);
          await client.auth.signInWithPassword(
            email: 'fixture@example.invalid',
            password: 'fixture',
          );
          final repository = SupabaseAdminExerciseRepository(
            client,
            ownerId: owner,
          );
          final entry = AdminExerciseTrashEntry(
            id: exerciseId,
            name: 'Dominada',
            trashedAt: stamp,
          );
          Future<void> mutate() => switch (status) {
            'trashed' => repository.trashExercise(
              exerciseId,
              operationId: operation,
            ),
            'restored' => repository.restoreExercise(
              entry,
              operationId: operation,
            ),
            _ => repository.purgeExercise(entry, operationId: operation),
          };
          await expectLater(mutate(), throwsStateError);
          confirmed = true;
          await mutate();
          expect(calls, hasLength(2));
          expect(calls.first, calls.last);
          expect(calls.last['p_operation_id'], operation);
        },
      );
    }
  }

  for (final disposition in ['confirmed', 'protected', 'unconfirmed']) {
    final protected = disposition == 'protected';
    test(
      'imagen fallida conserva medios salvo purga confirmada: $disposition',
      () async {
        final calls = <http.Request>[];
        var trashAttempts = 0;
        final client = clientFor((request) async {
          calls.add(request);
          if (request.url.path.endsWith('create_admin_exercise')) {
            return response(exerciseId);
          }
          if (request.url.path.endsWith('set_admin_exercise_image')) {
            return http.Response(
              jsonEncode({
                'code': 'P0001',
                'message': 'Respuesta de imagen perdida.',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('trash_admin_exercise')) {
            if (trashAttempts++ == 0) {
              throw http.ClientException('Respuesta perdida');
            }
            return response({
              'id': exerciseId,
              'kind': 'exercise',
              'trashed_at': stamp.toIso8601String(),
              'status': 'trashed',
            });
          }
          if (request.url.path.endsWith('purge_admin_exercise') && protected) {
            return http.Response(
              jsonEncode({
                'code': 'P0001',
                'message': 'La sesión conserva una referencia.',
              }),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('purge_admin_exercise')) {
            return http.Response(
              jsonEncode(
                disposition == 'unconfirmed'
                    ? null
                    : {
                        'id': exerciseId,
                        'kind': 'exercise',
                        'status': 'purged',
                      },
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return response({
            'Key': 'exercise-images-public/official/$exerciseId/image.jpg',
          });
        });
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'fixture@example.invalid',
          password: 'fixture',
        );
        await expectLater(
          SupabaseAdminExerciseRepository(
            client,
            ownerId: owner,
          ).createOfficial(
            const ExerciseDraft(
              name: 'Dominada',
              muscleGroups: ['espalda'],
              equipment: [],
              difficulty: 'inicial',
              exerciseType: 'repeticiones',
            ),
            image: ExerciseImageUpload(bytes: Uint8List.fromList([1, 2, 3])),
          ),
          throwsA(anything),
        );
        final moved = calls
            .where((call) => call.url.path.endsWith('trash_admin_exercise'))
            .toList();
        expect(moved, hasLength(2));
        expect(jsonDecode(moved.first.body), jsonDecode(moved.last.body));
        final purged = calls.singleWhere(
          (call) => call.url.path.endsWith('purge_admin_exercise'),
        );
        expect(
          jsonDecode(purged.body)['p_trashed_at'],
          stamp.toIso8601String(),
        );
        expect(
          jsonDecode(purged.body)['p_operation_id'],
          isNot(jsonDecode(moved.first.body)['p_operation_id']),
        );
        expect(
          calls.where(
            (call) =>
                call.method == 'DELETE' &&
                call.url.path == '/rest/v1/exercises',
          ),
          isEmpty,
        );
        expect(
          calls.where(
            (call) =>
                call.method == 'DELETE' && call.url.path.contains('/storage/'),
          ),
          isEmpty,
        );
      },
    );
  }

  test(
    'metadatos retirados se consultan por IDs sin reabrir catálogo público',
    () async {
      late http.Request call;
      final client = clientFor((request) async {
        call = request;
        return response([
          {
            'id': exerciseId,
            'name': 'Dominada retirada',
            'image_path': 'official/$exerciseId/demo.jpg',
          },
        ]);
      });
      addTearDown(client.dispose);
      final entries = await SupabaseAdminWorkoutRepository(client)
          .listRetainedExercises({exerciseId});
      expect(call.url.queryParameters['origin'], 'eq.system');
      expect(call.url.queryParameters['id'], 'in.("$exerciseId")');
      expect(call.url.queryParameters.containsKey('is_public'), isFalse);
      expect(entries.single.name, 'Dominada retirada');
      expect(
        entries.single.thumbnailUrl,
        contains('/exercise-images-public/official/$exerciseId/demo.jpg'),
      );
    },
  );

  test('catálogo activo excluye papelera e incluye oficiales retirados para revisar', () async {
    late http.Request call;
    final client = clientFor((request) async {
      call = request;
      return response([
        {
          'id': exerciseId,
          'name': 'Dominada',
          'difficulty': 'inicial',
          'exercise_type': 'repeticiones',
          'is_public': false,
        },
      ]);
    });
    addTearDown(client.dispose);
    final entries = await SupabaseAdminExerciseRepository(client)
        .listOfficial();
    expect(call.url.queryParameters['trashed_at'], 'is.null');
    expect(call.url.queryParameters['origin'], 'eq.system');
    expect(call.url.queryParameters.containsKey('is_public'), isFalse);
    expect(entries.single.isPublic, isFalse);
  });

  test('RPC conserva recibos, sello exacto y cursor; fija token a la identidad ADMIN', () async {
    final calls = <http.Request>[];
    final client = clientFor((request) async {
      calls.add(request);
      return response(
        request.url.path.endsWith('list_admin_exercise_trash')
            ? [
                {
                  'id': exerciseId,
                  'name': 'Dominada',
                  'kind': 'exercise',
                  'trashed_at': stamp.toIso8601String(),
                  'delete_block_reason': 'Utilizado en sesiones.',
                },
              ]
            : {
                'id': exerciseId,
                'kind': 'exercise',
                'status': request.url.path.endsWith('trash_admin_exercise')
                    ? 'trashed'
                    : request.url.path.endsWith('restore_admin_exercise')
                    ? 'restored'
                    : 'purged',
                'trashed_at': stamp.toIso8601String(),
              },
      );
    });
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'fixture',
    );
    final repository = SupabaseAdminExerciseRepository(client, ownerId: owner);
    final entry = (await repository.listExerciseTrash()).single;
    expect(entry.deleteBlockReason, 'Utilizado en sesiones.');
    await repository.listExerciseTrash(before: entry);
    expect(jsonDecode(calls.last.body), {
      'p_limit': 50,
      'p_before_at': stamp.toIso8601String(),
      'p_before_id': exerciseId,
    });
    await repository.trashExercise(exerciseId, operationId: operation);
    expect(jsonDecode(calls.last.body), {
      'p_id': exerciseId,
      'p_operation_id': operation,
    });
    await repository.restoreExercise(entry, operationId: operation);
    expect(calls.last.url.path, endsWith('/restore_admin_exercise'));
    await repository.purgeExercise(entry, operationId: operation);
    expect(calls.last.url.path, endsWith('/purge_admin_exercise'));
    expect(jsonDecode(calls.last.body), {
      'p_id': exerciseId,
      'p_operation_id': operation,
      'p_trashed_at': stamp.toIso8601String(),
    });
    for (final call in calls) {
      expect(
        call.headers['authorization'],
        'Bearer ${client.auth.currentSession!.accessToken}',
      );
    }
    final count = calls.length;
    await client.auth.signOut();
    await expectLater(
      repository.purgeExercise(entry, operationId: operation),
      throwsStateError,
    );
    expect(calls, hasLength(count));
  });

  test(
    'rechazo de permiso es definitivo y oculta diagnóstico interno',
    () async {
      final client = clientFor(
        (request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'diagnóstico interno'}),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      await expectLater(
        SupabaseAdminExerciseRepository(client, ownerId: owner).restoreExercise(
          AdminExerciseTrashEntry(
            id: exerciseId,
            name: 'Dominada',
            trashedAt: stamp,
          ),
          operationId: operation,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'mensaje seguro',
            allOf(contains('permiso'), isNot(contains('diagnóstico'))),
          ),
        ),
      );
    },
  );
}
