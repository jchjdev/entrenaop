import 'dart:convert';

import 'package:entrenaop_trainer/main.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';

const _owner = '10000000-0000-4000-8000-000000000001';

class _PortalFixture {
  Map<String, dynamic>? work;
  int workReads = 0;
  final requests = <String>[];
  final writes = <Map<String, dynamic>>[];
  late final client = SupabaseClient(
    'https://portal-fixture.example.invalid',
    'public-fixture',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final name = request.url.pathSegments.last;
      requests.add(name);
      final raw = request.body.isEmpty ? null : jsonDecode(request.body);
      final params = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final Object? result;
      switch (name) {
        case 'token':
          result = sessionData('refreshed');
        case 'get_my_trainer_account_status':
          result = {'professional_account': true, 'enabled': true};
        case 'get_trainer_security_status':
          result = true;
        case 'get_trainer_access':
          result = {
            'trainer_id': _owner,
            'enabled': true,
            'effective': true,
            'client_limit': 5,
            'active_clients': 0,
            'revision': 1,
          };
        case 'get_trainer_program_work':
          workReads++;
          expect(params['p_expected_owner'], _owner);
          result = work;
        case 'save_trainer_program_work':
          expect(params['p_expected_owner'], _owner);
          writes.add(params);
          work = {
            'id': params['p_id'],
            'state': params['p_state'],
            'revision': (params['p_revision'] as int) + 1,
            'base_program_id': params['p_base_program_id'],
            'finalized_program_id': null,
            'updated_at': '2026-10-21T17:00:00Z',
            'lifecycle': 'open',
            'context': 'trainer_private',
          };
          result = {
            'receipt': {'work': work},
            'current_revision': work!['revision'],
            'current_lifecycle': 'open',
          };
        case 'list_trainer_program_work':
          result = work == null ? [] : [work];
        default:
          result = [];
      }
      return http.Response(
        jsonEncode(result),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );

  Map<String, dynamic> sessionData(String suffix) {
    final claims = base64Url
        .encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': 4102444800})))
        .replaceAll('=', '');
    return {
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.$suffix',
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'user': {
        'id': _owner,
        'aud': 'authenticated',
        'role': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-10-21T00:00:00Z',
        'is_anonymous': false,
      },
    };
  }

  Future<void> session(String suffix) =>
      client.auth.setInitialSession(jsonEncode(sessionData(suffix)));
}

void main() {
  testWidgets(
    'la ruta real conserva UUID y campos al renovar sesión y retoma el checkpoint',
    (tester) async {
      final fixture = _PortalFixture();
      // La inicialización y el cierre comparten el event loop real del isolate
      // JSON del SDK; el widget conserva su reloj falso para probar el debounce.
      await tester.runAsync(() => fixture.session('initial'));
      expect(fixture.client.auth.currentSession!.isExpired, isFalse);
      addTearDown(() => tester.runAsync(fixture.client.dispose));
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(TrainerApp(client: fixture.client));
      await tester.pumpAndSettle();
      expect(
        find.byType(TrainerShell),
        findsOneWidget,
        reason: fixture.requests.join(','),
      );
      final router = GoRouter.of(tester.element(find.byType(TrainerShell)));
      router.go('/programs/new');
      await tester.pumpAndSettle();
      final location = router.routeInformationProvider.value.uri.toString();
      expect(location, matches(RegExp(r'^/programs/work/[0-9a-f-]{36}$')));
      expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
      final field = find.byKey(
        const ValueKey('program-field-Nombre del programa'),
      );
      final controller = tester.widget<TextFormField>(field).controller!;
      await tester.enterText(field, '  Mi programa a medias  ');
      final reads = fixture.workReads;

      // Una renovación del mismo titular refresca el router, no el editor.
      await fixture.session('renewed');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.toString(), location);
      expect(tester.widget<TextFormField>(field).controller, same(controller));
      expect(controller.text, '  Mi programa a medias  ');
      expect(fixture.workReads, reads);

      expect(fixture.writes, isEmpty);
      await tester.pump(const Duration(milliseconds: 599));
      expect(
        fixture.writes,
        isEmpty,
        reason: 'Todavía no han transcurrido los 700 ms de autosave.',
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(fixture.writes, hasLength(1));
      expect(
        fixture.writes.single['p_state']['name'],
        '  Mi programa a medias  ',
      );
      expect(fixture.writes.single['p_id'], location.split('/').last);
      router.go('/programs');
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramEditorPage), findsNothing);
      router.go(location);
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
      expect(fixture.workReads, greaterThan(reads));
      expect(router.routeInformationProvider.value.uri.toString(), location);
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        '  Mi programa a medias  ',
      );
      expect(fixture.writes, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
