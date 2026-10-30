import 'dart:async';
import 'dart:convert';

import 'package:entrenaop_trainer/trainer_personal_calendar_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trainer_access/trainer_calendar.dart';

import 'trainer_exercise_repository_test.dart' as auth;

class PersonalServer extends auth.ServerFixture {
  bool active = false;
  final queries = <Uri>[];
  final sharedCalls = <Map<String, dynamic>>[];
  Completer<void>? wait;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/rest/v1/trainer_client_relations') {
      queries.add(request.url);
      if (wait != null) await wait!.future;
      return super.json(
        request,
        active
            ? [
                {'id': 'self'},
              ]
            : [],
      );
    }
    if (request.url.path.endsWith('/rpc/get_trainer_shared_calendar')) {
      sharedCalls.add(jsonDecode(request.body) as Map<String, dynamic>);
      return super.json(request, {
        'shared': true,
        'has_more': false,
        'items': [],
        'coaches': [],
      });
    }
    return super.handle(request);
  }
}

void main() {
  late PersonalServer server;
  late SupabaseTrainerPersonalCalendarRepository repository;
  final from = DateTime(2026, 11), to = DateTime(2026, 11, 30);
  setUp(() async {
    server = PersonalServer();
    await server.login();
    repository = SupabaseTrainerPersonalCalendarRepository(
      server.client,
      auth.owner,
    );
  });
  tearDown(() => server.client.dispose());

  test('sin Para mí activado no crea vínculo ni consulta carteras', () async {
    final page = await repository.calendar(auth.owner, from, to);
    expect(page.entries, isEmpty);
    expect(server.sharedCalls, isEmpty);
    final query = server.queries.single.queryParameters;
    expect(query['trainer_id'], 'eq.${auth.owner}');
    expect(query['client_id'], 'eq.${auth.owner}');
    expect(query['ended_at'], 'is.null');
  });

  test(
    'reutiliza el lector autorizado solo para el propietario y conserva cursor',
    () async {
      server.active = true;
      final after = SharedCalendarEntry.fromJson({
        'id': 'last',
        'scheduled_date': '2026-11-03',
        'template_name': 'Anterior',
        'source': 'coach',
        'status': 'planned',
      });
      await repository.calendar(auth.owner, from, to, after: after);
      expect(server.sharedCalls.single, {
        'p_expected_owner': auth.owner,
        'p_client_id': auth.owner,
        'p_from': '2026-11-01',
        'p_to': '2026-11-30',
        'p_after_date': '2026-11-03',
        'p_after_id': 'last',
      });
    },
  );

  test('no permite usar el adaptador personal para otro alumno', () async {
    await expectLater(repository.calendar('other', from, to), throwsStateError);
    expect(() => repository.workout('other', 'session'), throwsStateError);
    expect(server.queries, isEmpty);
    expect(server.sharedCalls, isEmpty);
  });

  test(
    'descarta la comprobación si cambia la cuenta antes de responder',
    () async {
      server.active = true;
      server.wait = Completer<void>();
      final request = repository.calendar(auth.owner, from, to);
      final check = expectLater(request, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await server.client.auth.signOut();
      server.wait!.complete();
      await check;
      expect(server.sharedCalls, isEmpty);
    },
  );
}
