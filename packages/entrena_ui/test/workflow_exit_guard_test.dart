import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
