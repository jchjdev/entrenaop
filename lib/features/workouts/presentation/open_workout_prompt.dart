import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../domain/entities/open_workout_session.dart';
import '../domain/usecases/workout_execution_usecases.dart';

enum _OpenWorkoutChoice { resume, discard }

Future<void> startWithOpenWorkoutPrompt(
  BuildContext context,
  Future<void> Function() start,
) async {
  while (context.mounted) {
    try {
      await start();
      return;
    } on OpenWorkoutConflict catch (conflict) {
      if (!context.mounted) return;
      final choice = await showDialog<_OpenWorkoutChoice>(
        context: context,
        builder: (dialogContext) => EntrenaDialog(
          title: const Text('Ya tienes una sesión en curso'),
          content: Text(conflict.name),
          actions: [
            EntrenaDialogActions(
              primaryLabel: 'Continuar sesión abierta',
              onPrimary: () =>
                  Navigator.pop(dialogContext, _OpenWorkoutChoice.resume),
              secondary: [
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _OpenWorkoutChoice.discard),
                  child: const Text('Descartar y empezar esta'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      );
      if (!context.mounted || choice == null) return;
      if (choice == _OpenWorkoutChoice.resume) {
        await context.push('/plan/week/active/${conflict.executionId}');
        return;
      }
      if (!await confirmWorkoutDiscard(context, replacing: true) ||
          !context.mounted) {
        return;
      }
      try {
        await sl<DiscardWorkoutExecutionUseCase>()(conflict.executionId);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se ha podido descartar la sesión. Reintenta.'),
            ),
          );
        }
        return;
      }
    }
  }
}

Future<bool> confirmWorkoutDiscard(
  BuildContext context, {
  bool replacing = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => EntrenaDialog(
          title: const Text('¿Descartar esta sesión?'),
          content: const Text(
            'Se eliminarán esta sesión y sus series registradas. No quedará en el '
            'historial. Si estaba en tu agenda, volverá a estar pendiente.\n\n'
            'No se puede deshacer y necesita conexión.',
          ),
          actions: [
            EntrenaDialogActions(
              primaryLabel: replacing ? 'Cancelar' : 'Continuar',
              onPrimary: () => Navigator.pop(dialogContext, false),
              secondary: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: EntrenaButtonStyles.destructive(dialogContext),
                  child: Text(
                    replacing ? 'Confirmar descarte' : 'Descartar y salir',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ) ==
      true;
}
