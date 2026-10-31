import 'dart:async';
import 'dart:convert' show jsonDecode;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trainer_access/published_warmup_catalog.dart';

import 'trainer_exercise_repository_test.dart' show ServerFixture, owner;

class WarmupServer extends ServerFixture {
  final cursors = <Object?>[];
  Completer<void>? hold;
  bool repeats = false;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (!request.url.path.endsWith('/rpc/list_published_workout_warmups')) {
      return super.handle(request);
    }
    final body = jsonDecode(request.body) as Map;
    expect(body['p_expected_owner'], owner);
    final after = body['p_after_id'];
    cursors.add(after);
    await hold?.future;
    return super.json(request, {
      'items': [template(after == null || repeats ? 'a' : 'b')],
      'has_more': after == null,
    });
  }
}

Map<String, Object?> template(String id) => {
  'id': id,
  'name': 'Calentamiento $id',
  'version': 2,
  'workout_blocks': [
    {
      'id': 'block-$id',
      'order_index': 0,
      'name': 'Activación',
      'format': 'warm_up',
      'rounds': 1,
      'rest_after_seconds': 0,
      'workout_items': [
        {
          'id': 'item-$id',
          'order_index': 0,
          'exercises': {'id': 'official', 'name': 'Sentadilla'},
          'workout_sets': [
            for (final n in [1, 2])
              {
                'id': 'set-$id-$n',
                'order_index': n,
                'target_reps': n * 5,
                'rest_after_seconds': 30,
              },
          ],
        },
      ],
    },
  ],
};
void main() {
  test(
    'lee todas las páginas conservando dosis y versión de la receta',
    () async {
      final server = WarmupServer();
      addTearDown(server.client.dispose);
      await server.login();
      final items = await SupabasePublishedWarmupCatalog(
        server.client,
        owner,
      ).load();
      expect(server.cursors, [null, 'a']);
      expect(items.map((e) => e.id), ['a', 'b']);
      expect(items.first.version, 2);
      expect(
        items.first.blocks.single.items.single.sets.map((e) => e.targetReps),
        [5, 10],
      );
    },
  );
  test('rechaza una página que no avanza en vez de duplicar o bloquear el catálogo', () async {
    final server = WarmupServer()..repeats = true;
    addTearDown(server.client.dispose);
    await server.login();
    await expectLater(
      SupabasePublishedWarmupCatalog(server.client, owner).load(),
      throwsFormatException,
    );
  });
  test(
    'descarta la respuesta si la cuenta cierra sesión durante la lectura',
    () async {
      final server = WarmupServer()..hold = Completer<void>();
      addTearDown(server.client.dispose);
      await server.login();
      final operation = SupabasePublishedWarmupCatalog(
        server.client,
        owner,
      ).load();
      final result = expectLater(operation, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await server.client.auth.signOut();
      server.hold!.complete();
      await result;
    },
  );
}
