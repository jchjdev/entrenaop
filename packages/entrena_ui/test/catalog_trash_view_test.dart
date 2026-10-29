import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogTrashItem entry(String id, {String? blockedReason}) => CatalogTrashItem(
  id: id,
  name: 'Sesión $id',
  kind: 'session',
  trashedAt: DateTime.utc(2026, 10, 29, 15, 2, 3, 456, 789),
  blockedReason: blockedReason,
);

Future<void> noop(CatalogTrashItem item, String operationId) async {}

Widget app({
  Object owner = 'javier',
  required Future<List<CatalogTrashItem>> Function() load,
  Future<List<CatalogTrashItem>> Function(CatalogTrashItem)? loadMore,
  Future<void> Function(CatalogTrashItem, String) restore = noop,
  Future<void> Function(CatalogTrashItem, String) delete = noop,
  String Function()? operationId,
  int pageSize = 50,
  double scale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: CatalogTrashView(
      title: 'Papelera de sesiones',
      ownerKey: owner,
      load: load,
      loadMore: loadMore,
      pageSize: pageSize,
      onRestore: restore,
      onDelete: delete,
      newOperationId: operationId ?? () => 'operation-1',
    ),
  ),
);

void main() {
  testWidgets('un uso protegido bloquea purga pero permite recuperar', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        load: () async => [
          entry('A', blockedReason: 'Tiene resultados registrados.'),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Tiene resultados registrados.'), findsOneWidget);
    final purge = t.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Borrar definitivamente'),
    );
    final restore = t.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Recuperar sesión'),
    );
    expect(purge.onPressed, isNull);
    expect(restore.onPressed, isNotNull);
  });

  testWidgets('cancelar la confirmación final no envía una purga', (t) async {
    var writes = 0;
    await t.pumpWidget(
      app(
        load: () async => [entry('A')],
        delete: (_, _) async {
          writes++;
        },
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Borrar definitivamente'));
    await t.pumpAndSettle();
    expect(find.text('¿Borrar para siempre?'), findsOneWidget);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Sesión A'), findsOneWidget);
  });

  testWidgets(
    'respuesta perdida conserva recibo y sello incluso al actualizar',
    (t) async {
      final calls = <(String, DateTime)>[];
      var nextId = 0;
      var removed = false;
      final item = entry('A');
      await t.pumpWidget(
        app(
          load: () async => removed ? [] : [item],
          operationId: () => 'op-${++nextId}',
          delete: (item, operation) async {
            calls.add((operation, item.trashedAt));
            if (calls.length == 1) throw StateError('respuesta perdida');
            removed = true;
          },
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Borrar definitivamente'));
      await t.pumpAndSettle();
      await t.tap(find.text('Borrar para siempre'));
      await t.pumpAndSettle();
      expect(find.text('Reintentar borrado'), findsOneWidget);
      await t.tap(find.text('Actualizar papelera'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reintentar borrado'));
      await t.pumpAndSettle();
      expect(calls, [('op-1', item.trashedAt), ('op-1', item.trashedAt)]);
      expect(nextId, 1);
      expect(find.text('La papelera está vacía.'), findsOneWidget);
    },
  );

  testWidgets('rechazo definitivo no conserva una operación incierta', (
    t,
  ) async {
    var nextId = 0;
    final calls = <String>[];
    await t.pumpWidget(
      app(
        load: () async => [entry('A')],
        operationId: () => 'op-${++nextId}',
        restore: (_, operation) async {
          calls.add(operation);
          if (calls.length == 1) {
            throw const FormatException('La papelera ha cambiado. Actualiza.');
          }
        },
      ),
    );
    await t.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await t.tap(find.text('Recuperar sesión'));
      await t.pumpAndSettle();
      await t.tap(find.text('Recuperar').last);
      await t.pumpAndSettle();
    }
    expect(calls, ['op-1', 'op-2']);
    expect(find.text('Reintentar recuperación'), findsNothing);
  });

  testWidgets('respuesta de la cuenta anterior no entra en la cuenta nueva', (
    t,
  ) async {
    final previous = Completer<List<CatalogTrashItem>>();
    await t.pumpWidget(app(owner: 'A', load: () => previous.future));
    await t.pump();
    await t.pumpWidget(app(owner: 'B', load: () async => [entry('B')]));
    await t.pumpAndSettle();
    previous.complete([entry('A')]);
    await t.pumpAndSettle();
    expect(find.text('Sesión B'), findsOneWidget);
    expect(find.text('Sesión A'), findsNothing);
  });

  testWidgets('cambio de cuenta invalida una mutación pendiente y su recibo', (
    t,
  ) async {
    final previous = Completer<void>();
    await t.pumpWidget(
      app(
        owner: 'A',
        load: () async => [entry('A')],
        restore: (_, _) => previous.future,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Recuperar sesión'));
    await t.pumpAndSettle();
    await t.tap(find.text('Recuperar').last);
    await t.pump();
    await t.pumpWidget(app(owner: 'B', load: () async => [entry('B')]));
    await t.pumpAndSettle();
    previous.complete();
    await t.pumpAndSettle();
    expect(find.text('Sesión B'), findsOneWidget);
    expect(find.textContaining('Operación pendiente'), findsNothing);
    expect(find.textContaining('Contenido recuperado'), findsNothing);
  });

  testWidgets(
    'cargar más continúa desde el último sello sin duplicar entradas',
    (t) async {
      CatalogTrashItem? cursor;
      await t.pumpWidget(
        app(
          load: () async => [entry('A'), entry('B')],
          pageSize: 2,
          loadMore: (after) async {
            cursor = after;
            return [entry('B'), entry('C')];
          },
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Cargar más'));
      await t.tap(find.text('Cargar más'));
      await t.pumpAndSettle();
      expect(cursor?.id, 'B');
      expect(cursor?.trashedAt, entry('B').trashedAt);
      expect(find.text('Sesión B'), findsOneWidget);
      expect(find.text('Sesión C'), findsOneWidget);
    },
  );

  testWidgets('recuperación confirmada no se confunde con fallo de recarga', (
    t,
  ) async {
    var restored = false;
    await t.pumpWidget(
      app(
        load: () async {
          if (restored) throw StateError('red caída al recargar');
          return [entry('A')];
        },
        restore: (_, _) async {
          restored = true;
        },
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Recuperar sesión'));
    await t.pumpAndSettle();
    await t.tap(find.text('Recuperar').last);
    await t.pumpAndSettle();
    expect(restored, isTrue);
    expect(
      find.text('No se pudo cargar la papelera. Vuelve a intentarlo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar recuperación'), findsNothing);
    expect(find.textContaining('Contenido recuperado'), findsOneWidget);
  });

  testWidgets('320px y texto doble conservan decisiones sin desbordar', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      app(
        scale: 2,
        load: () async => [entry('con nombre largo de tirón y sentadillas')],
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(
      find.text('Borrar definitivamente'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Borrar definitivamente'));
    await t.pumpAndSettle();
    expect(find.text('¿Borrar para siempre?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
