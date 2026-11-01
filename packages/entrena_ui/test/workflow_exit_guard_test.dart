import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'aceptar una salida conserva la guarda de una vista que sigue montada',
    (tester) async {
      final registry = WorkflowExitRegistry();
      const key = ValueKey('conversacion-conservada');
      final controller = registry.controller(key);
      var allowed = true;
      var busy = false;
      var checks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowExitScope(
            controller: controller,
            child: WorkflowDraftGuard(
              hasUnsavedChanges: () => false,
              isBusy: () => busy,
              beforeExit: () async {
                checks++;
                return allowed;
              },
              child: const Scaffold(),
            ),
          ),
        ),
      );
      expect(await registry.requestExit(key), isTrue);
      allowed = false;
      expect(await registry.requestExit(key), isFalse);
      expect(checks, 2);
      allowed = true;
      busy = true;
      expect(await registry.requestExit(key), isFalse);
      expect(checks, 2);
      busy = false;
      expect(await registry.requestExit(key), isTrue);
      expect(checks, 3);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.onExit, isNull);
      expect(registry.controller(key), isNot(same(controller)));
    },
  );

  test(
    'la salida pendiente de una vista antigua no borra su sustituta',
    () async {
      final registry = WorkflowExitRegistry();
      const key = ValueKey('misma-ruta');
      final old = registry.controller(key);
      final pending = Completer<bool>();
      old.onExit = () => pending.future;
      final leaving = registry.requestExit(key);
      old.onExit = null;
      final replacement = registry.controller(key);
      expect(replacement, isNot(same(old)));
      replacement.onExit = () async => false;
      pending.complete(true);
      expect(await leaving, isTrue);
      expect(registry.controller(key), same(replacement));
      expect(await registry.requestExit(key), isFalse);
      old.onExit = null;
      expect(registry.controller(key), same(replacement));
      old.onExit = () async => true;
      expect(registry.controller(key), same(replacement));
      expect(await registry.requestExit(key), isFalse);
      old.onExit = null;
    },
  );

  test(
    'volver a registrar un controlador conservado reactiva su guarda',
    () async {
      final registry = WorkflowExitRegistry();
      const key = ValueKey('rama-conservada');
      final controller = registry.controller(key);
      controller.onExit = () async => true;
      controller.onExit = null;
      controller.onExit = () async => false;
      expect(registry.controller(key), same(controller));
      expect(await registry.requestExit(key), isFalse);
      controller.onExit = null;
      expect(registry.controller(key), isNot(same(controller)));
    },
  );

  testWidgets(
    'el editor contenido puede vetar la salida de una página limpia',
    (tester) async {
      final controller = WorkflowExitController();
      var allowed = false;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowExitScope(
            controller: controller,
            child: WorkflowDraftGuard(
              hasUnsavedChanges: () => false,
              beforeExit: () async => allowed,
              saveDraftBeforeExit: () async {
                saves++;
                return true;
              },
              child: const Scaffold(),
            ),
          ),
        ),
      );
      expect(await controller.onExit!(), isFalse);
      expect(saves, 0);
      allowed = true;
      expect(await controller.onExit!(), isTrue);
      expect(saves, 1);
    },
  );

  testWidgets(
    'una operación en curso se comprueba antes de la salida contenida',
    (tester) async {
      final controller = WorkflowExitController();
      var busy = true;
      var checks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowExitScope(
            controller: controller,
            child: WorkflowDraftGuard(
              hasUnsavedChanges: () => false,
              isBusy: () => busy,
              beforeExit: () async {
                checks++;
                return true;
              },
              child: const Scaffold(),
            ),
          ),
        ),
      );
      expect(await controller.onExit!(), isFalse);
      expect(checks, 0);
      busy = false;
      expect(await controller.onExit!(), isTrue);
      expect(checks, 1);
    },
  );
}
