import 'apple_training.dart';

abstract interface class AppleTrainingSyncPreference {
  Future<bool> enabled(String owner);
  Future<void> setEnabled(String owner, bool value);
}

class AppleTrainingSyncReport {
  const AppleTrainingSyncReport(this.catalog, this.failures);
  final AppleCatalog catalog;
  final Map<String, String> failures;
}

/// Concilia la agenda autorizada con WorkoutKit; un recibo del servidor no
/// demuestra que la pauta siga presente en este iPhone.
class SyncAppleTraining {
  SyncAppleTraining(this.service, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final AppleTrainingService service;
  final DateTime Function() now;

  Future<AppleTrainingSyncReport> call(bool Function() active) async {
    final repository = service.repository;
    void check() {
      if (!repository.isCurrent) {
        throw const AppleTrainingFailure('account_changed');
      }
      if (!active()) throw const AppleTrainingFailure('sync_cancelled');
    }

    check();
    if (await service.scheduler.status() != AppleAuthorization.authorized) {
      throw const AppleTrainingFailure('permission_required');
    }
    check();
    final catalog = await repository.load();
    check();
    final receipts = {for (final row in catalog.receipts) row.id: row};
    final failures = <String, String>{};
    final date = now();
    final today = DateTime(date.year, date.month, date.day);
    final candidates = {for (final row in catalog.candidates) row.id};
    final ids = <String>{
      // Retiradas primero: liberan capacidad sin borrar el historial pasado.
      for (final row in catalog.receipts)
        if (row.status != 'removed' && !row.started && row.needsRemoval) row.id,
      for (final row in catalog.receipts)
        if (row.status != 'removed' &&
            !row.started &&
            (row.needsRemoval ||
                !(DateTime.tryParse(row.date)?.isBefore(today) ?? true)))
          row.id,
      ...candidates,
    };
    for (final id in ids) {
      check();
      final receipt = receipts[id];
      if (receipt?.started == true) continue;
      try {
        if (receipt?.needsRemoval == true) {
          if (receipt!.status != 'removed') {
            await service.withdraw(id, canContinue: active);
          }
          continue;
        }
        // La pérdida del derecho comercial impide nuevas entregas; no impide
        // retirar una cancelación ni se interpreta como una cancelación.
        if (!catalog.allowed) continue;
        final preview = await repository.preview(id);
        check();
        if (receipt?.planId case final planId?) {
          final local = await service.scheduler.inspect(
            repository.ownerId,
            ApplePlan(preview.prescription, preview.revision, planId, null),
          );
          check();
          if (local == AppleScheduledState.completed) continue;
          if (local == AppleScheduledState.matching &&
              receipt!.status == 'submitted' &&
              receipt.revision == preview.revision) {
            continue;
          }
        }
        await service.send(id, preview, canContinue: active);
      } on AppleTrainingFailure catch (error) {
        check();
        // No inferir una retirada por ausencia en una lista limitada. La
        // consulta individual confirma archivo, cancelación o cambio de fecha.
        if (receipt != null &&
            receipt.status != 'removed' &&
            {
              'source_not_available',
              'source_not_allowed',
              'date_outside_window',
            }.contains(error.code)) {
          try {
            await service.withdraw(id, canContinue: active);
          } on AppleTrainingFailure catch (removalError) {
            check();
            failures[id] = removalError.code;
          }
        } else if (error.code != 'already_completed') {
          failures[id] = error.code;
        }
      }
    }
    check();
    final updated = await repository.load();
    check();
    return AppleTrainingSyncReport(updated, Map.unmodifiable(failures));
  }
}
