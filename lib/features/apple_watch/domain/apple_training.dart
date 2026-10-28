enum AppleAuthorization {
  unsupported,
  notDetermined,
  authorized,
  denied,
  restricted,
}

class AppleTrainingFailure implements Exception {
  const AppleTrainingFailure(this.code);
  final String code;
}

class AppleStep {
  const AppleStep(
    this.kind,
    this.measure,
    this.value,
    this.description,
    this.fast,
    this.slow,
  );
  final String kind, measure, description;
  final num? value, fast, slow;
}

class ApplePrescription {
  ApplePrescription(this.name, this.date, List<AppleStep> steps)
    : steps = List.unmodifiable(steps);
  final String name, date;
  final List<AppleStep> steps;
}

class AppleCandidate {
  const AppleCandidate(this.id, this.name, this.date);
  final String id, name, date;
}

class AppleReceipt {
  const AppleReceipt(
    this.id,
    this.name,
    this.date,
    this.revision,
    this.status,
    this.needsRemoval,
    this.started,
  );
  final String id, name, date, revision, status;
  final bool needsRemoval, started;
}

class AppleCatalog {
  const AppleCatalog(this.allowed, this.candidates, this.receipts);
  final bool allowed;
  final List<AppleCandidate> candidates;
  final List<AppleReceipt> receipts;
}

class ApplePlan {
  const ApplePlan(
    this.prescription,
    this.revision,
    this.planId,
    this.attemptId,
  );
  final ApplePrescription prescription;
  final String revision;
  final String? planId, attemptId;
}

class AppleRemoval {
  const AppleRemoval(this.planId, this.revision, this.attemptId);
  final String planId, revision, attemptId;
}

abstract interface class AppleTrainingRepository {
  String get ownerId;
  bool get isCurrent;
  Future<AppleCatalog> load();
  Future<ApplePlan> preview(String id);
  Future<ApplePlan> prepare(String id, String revision);
  Future<void> record(String id, ApplePlan plan);
  Future<AppleRemoval> removal(String id);
  Future<void> removed(String id, AppleRemoval removal);
}

abstract interface class AppleWorkoutScheduler {
  Future<AppleAuthorization> status();
  Future<AppleAuthorization> authorize();
  Future<void> schedule(String owner, ApplePlan plan);
  Future<void> remove(String owner, String planId);
}

// Orquestación común: ninguna pantalla decide permisos ni traduce para Apple.
class AppleTrainingService {
  AppleTrainingService(this.repository, this.scheduler);
  final AppleTrainingRepository repository;
  final AppleWorkoutScheduler scheduler;
  bool _busy = false;
  void _check() {
    if (!repository.isCurrent) {
      throw const AppleTrainingFailure('account_changed');
    }
  }

  Future<void> send(String id, ApplePlan preview) => _run(() async {
    if (await scheduler.status() != AppleAuthorization.authorized) {
      throw const AppleTrainingFailure('permission_required');
    }
    _check();
    final plan = await repository.prepare(id, preview.revision);
    _check();
    await scheduler.schedule(repository.ownerId, plan);
    _check();
    await repository.record(id, plan);
  });
  Future<void> withdraw(String id) => _run(() async {
    final removal = await repository.removal(id);
    _check();
    await scheduler.remove(repository.ownerId, removal.planId);
    _check();
    await repository.removed(id, removal);
  });
  Future<void> _run(Future<void> Function() action) async {
    _check();
    if (_busy) throw const AppleTrainingFailure('connection_busy');
    _busy = true;
    try {
      await action();
      _check();
    } finally {
      _busy = false;
    }
  }
}
