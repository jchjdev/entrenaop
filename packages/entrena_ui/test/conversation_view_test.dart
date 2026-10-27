import 'dart:async';

import 'package:entrena_ui/conversation_view.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'consulta lenta no se solapa y no acredita lectura bajo otra pantalla',
    (t) async {
      var calls = 0;
      final pending = Completer<List<ConversationEntry>>();
      final displayed = <String>[];
      ConversationEntry entry(String id) => ConversationEntry(
        id: id,
        body: id,
        createdAt: DateTime(2026, 10, 27),
        mine: false,
      );
      await t.pumpWidget(
        MaterialApp(
          home: ConversationView(
            refreshInterval: const Duration(seconds: 15),
            header: () async =>
                const ConversationHeader(title: 'Alumno', canSend: true),
            load: (_) async {
              calls++;
              return calls == 2 ? pending.future : [entry('$calls')];
            },
            onDisplayed: (rows) async =>
                displayed.addAll(rows.map((r) => r.id)),
            send: (_, _) async {},
            newOperationId: () => 'id',
            errorLabel: (_) => 'Error',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 15));
      await t.pump(const Duration(seconds: 45));
      expect(calls, 2);
      final navigator = t.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Otra pantalla')),
          ),
        ),
      );
      await t.pumpAndSettle();
      pending.complete([entry('oculto')]);
      await t.pumpAndSettle();
      expect(displayed, ['1']);
      await t.pump(const Duration(seconds: 30));
      expect(calls, 2);
      navigator.pop();
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 15));
      await t.pumpAndSettle();
      expect(calls, 3);
      expect(displayed, ['1', '3']);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'refresco automático conserva borrador, pausa oculta y recupera al volver',
    (t) async {
      var calls = 0;
      final shown = <List<String>>[];
      await t.pumpWidget(
        MaterialApp(
          home: ConversationView(
            refreshInterval: const Duration(seconds: 15),
            header: () async =>
                const ConversationHeader(title: 'Alumno', canSend: true),
            load: (_) async {
              calls++;
              return [
                ConversationEntry(
                  id: '$calls',
                  body: 'Respuesta $calls',
                  createdAt: DateTime(2026, 10, 27, 10, calls),
                  mine: false,
                ),
              ];
            },
            onDisplayed: (rows) async =>
                shown.add(rows.map((r) => r.id).toList()),
            send: (_, _) async {},
            newOperationId: () => 'id',
            errorLabel: (_) => 'Error',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'No perder mi borrador');
      await t.pump(const Duration(seconds: 15));
      await t.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Respuesta 2'), findsOneWidget);
      expect(find.text('Respuesta 1'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'No perder mi borrador',
      );
      expect(shown.last, ['2']);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await t.pump(const Duration(seconds: 45));
      expect(calls, 2);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(calls, 3);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 30));
      expect(calls, 3);
    },
  );

  testWidgets('refresco conserva las páginas anteriores cargadas', (t) async {
    var pages = 0;
    var newestCalls = 0;
    ConversationEntry entry(int n) => ConversationEntry(
      id: '$n',
      body: 'Mensaje $n',
      createdAt: DateTime(2026, 10, 27, 0, n),
      mine: true,
    );
    await t.pumpWidget(
      MaterialApp(
        home: ConversationView(
          refreshInterval: const Duration(seconds: 15),
          header: () async =>
              const ConversationHeader(title: 'Alumno', canSend: false),
          load: (before) async {
            if (before != null) {
              pages++;
              return [entry(0)];
            }
            newestCalls++;
            return [for (var i = 50; i > 0; i--) entry(i)];
          },
          send: (_, _) async {},
          newOperationId: () => 'id',
          errorLabel: (_) => 'Error',
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Cargar mensajes anteriores'),
      500,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Cargar mensajes anteriores'));
    await t.pumpAndSettle();
    expect(pages, 1);
    await t.pump(const Duration(seconds: 15));
    await t.pumpAndSettle();
    expect(newestCalls, 2);
    expect(find.text('Cargar mensajes anteriores'), findsNothing);
    expect(find.text('Mensaje 0'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'envío incierto conserva texto e identidad y permite recuperar recibo tras baja',
    (tester) async {
      var enabled = true;
      var fail = true;
      var sequence = 0;
      final sent = <(String, String)>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ConversationView(
            header: () async =>
                ConversationHeader(title: 'Alumno', canSend: enabled),
            load: (_) async => [],
            send: (id, body) async {
              sent.add((id, body));
              if (fail) throw StateError('Sin confirmar');
            },
            newOperationId: () => 'op-${++sequence}',
            errorLabel: (_) => 'Sin confirmar',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Técnica revisada  ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(sent, [('op-1', 'Técnica revisada')]);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      enabled = false;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('conservada en consulta'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar el mismo envío'));
      await tester.pumpAndSettle();
      expect(sent, [
        ('op-1', 'Técnica revisada'),
        ('op-1', 'Técnica revisada'),
      ]);
      expect(sequence, 1);
      expect(find.byType(TextField), findsNothing);
    },
  );

  for (final width in [320.0, 1200.0]) {
    testWidgets('consulta histórica legible a $width con texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ConversationView(
            header: () async => const ConversationHeader(
              title: 'Servicio anterior',
              canSend: false,
            ),
            load: (_) async => [
              ConversationEntry(
                id: 'old',
                body: 'Mensaje conservado de la preparación.',
                createdAt: DateTime.utc(2026, 10, 21, 10),
                mine: true,
              ),
            ],
            send: (_, _) async => fail('Histórico no debe enviar'),
            newOperationId: () => 'op',
            errorLabel: (_) => 'Error',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Mensaje conservado de la preparación.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('borrador activa guard de salida y conserva texto al continuar', (
    tester,
  ) async {
    final exit = WorkflowExitController();
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: WorkflowExitScope(
          controller: exit,
          child: ConversationView(
            header: () async =>
                const ConversationHeader(title: 'Preparador', canSend: true),
            load: (_) async => [],
            send: (_, _) async {},
            newOperationId: () => 'op',
            errorLabel: (_) => 'Error',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mi borrador');
    final leaving = exit.onExit!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(await leaving, isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Mi borrador',
    );
  });
  testWidgets(
    'escritorio mantiene el mensaje y el envío visibles al recorrer el historial',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1400, 900);
      addTearDown(t.view.reset);
      final attempts = <(String, String)>[];
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: ProfessionalWorkspaceScope(
            desktop: true,
            child: ConversationView(
              header: () async =>
                  const ConversationHeader(title: 'Alumno', canSend: true),
              load: (_) async => List.generate(
                25,
                (i) => ConversationEntry(
                  id: '$i',
                  body: 'Mensaje $i',
                  createdAt: DateTime(2026, 10, 25),
                  mine: i.isEven,
                ),
              ),
              send: (id, text) async {
                attempts.add((id, text));
                throw StateError('Sin confirmar');
              },
              newOperationId: () => 'única',
              errorLabel: (_) => 'Sin confirmar',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Revisión pendiente');
      final position = t.getTopLeft(find.byType(TextField));
      await t.drag(find.byType(ListView), const Offset(0, -1800));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byType(TextField)), position);
      expect(find.text('Enviar mensaje').hitTestable(), findsOneWidget);
      await t.tap(find.text('Enviar mensaje'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.tap(find.text('Reintentar el mismo envío'));
      await t.pumpAndSettle();
      expect(attempts, [
        ('única', 'Revisión pendiente'),
        ('única', 'Revisión pendiente'),
      ]);
      expect(t.takeException(), isNull);
    },
  );
}
