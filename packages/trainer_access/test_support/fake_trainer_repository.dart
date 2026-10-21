import 'package:trainer_access/trainer_access.dart';

class FakeTrainerRepository implements TrainerRepository {
  TrainerAccess current = TrainerAccess.fromJson({
    'trainer_id': 'trainer-a',
    'enabled': true,
    'effective': true,
    'client_limit': 3,
    'active_clients': 0,
    'revision': 1,
  });
  List<TrainerRelation> active = [], history = [];
  List<TrainerInvitation> invites = [];
  List<TrainerInvitationDraft> drafts = [];
  List<TrainerAccessChange> changes = [];
  bool managementEnabled = true;
  int accepts = 0, previews = 0, ends = 0;
  Object? createError, saveError, previewError;
  Future<List<TrainerRelation>> Function()? relationsOverride;
  @override
  Future<TrainerAccess> access() async => current;
  @override
  Future<List<TrainerRelation>> relations({
    required bool asTrainer,
    bool ended = false,
    TrainerRelation? before,
  }) async => relationsOverride == null
      ? (ended ? history : active)
      : relationsOverride!();
  @override
  Future<List<TrainerInvitation>> invitations({
    TrainerInvitation? before,
  }) async => invites;
  @override
  Future<void> createInvitation(TrainerInvitationDraft draft) async {
    drafts.add(draft);
    if (createError != null) throw createError!;
  }

  @override
  Future<TrainerInvitationPreview> preview(String secret) async {
    previews++;
    if (previewError != null) throw previewError!;
    return TrainerInvitationPreview.fromJson({
      'trainer_id': 'trainer-a',
      'trainer_name': 'Preparador A',
      'expires_at': '2030-01-01T00:00:00Z',
    });
  }

  @override
  Future<void> accept(String secret) async {
    accepts++;
    active = [trainerRelation('Preparador A')];
  }

  @override
  Future<void> cancelInvitation(String id) async {}
  @override
  Future<void> endRelation(String id) async {
    ends++;
    history = active.map((v) => trainerRelation(v.name, ended: true)).toList();
    active = [];
  }

  @override
  Future<TrainerManagement> management(String trainerId) async =>
      TrainerManagement.fromJson({
        'manual_access_enabled': managementEnabled,
        'access': {
          'trainer_id': trainerId,
          'enabled': current.enabled,
          'effective': current.effective,
          'client_limit': current.limit,
          'active_clients': current.activeClients,
          'revision': current.revision,
        },
      });
  @override
  Future<TrainerAccess> changeAccess(TrainerAccessChange change) async {
    changes.add(change);
    if (saveError != null) throw saveError!;
    return current;
  }

  @override
  Future<List<ManagedTrainer>> managedTrainers({String? afterId}) async => [];
}

TrainerRelation trainerRelation(String name, {bool ended = false}) =>
    TrainerRelation.fromJson({
      'id': 'relation-a',
      'person_id': 'person-a',
      'person_name': name,
      'accepted_at': '2026-10-01T00:00:00Z',
      'ended_at': ended ? '2026-10-02T00:00:00Z' : null,
    });
