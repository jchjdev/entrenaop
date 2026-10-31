import '../directory/domain.dart';
import '../trainer_message.dart';

enum ContactState { fresh, pending, accepted, declined, blocked }

class ContactConversation {
  const ContactConversation({
    this.id,
    this.profileId,
    this.relationId,
    this.requesterId,
    this.name = 'Conversación',
    this.state = ContactState.fresh,
    this.isTrainer = false,
    this.canSend = false,
    this.createdAt,
  });
  final String? id, profileId, relationId, requesterId;
  final String name;
  final ContactState state;
  final bool isTrainer, canSend;
  final DateTime? createdAt;
  bool get canDecide =>
      isTrainer && state == ContactState.pending && relationId == null;
}

class ContactInbox {
  const ContactInbox(this.items, {this.pendingCount = 0});
  final List<ContactConversation> items;
  final int pendingCount;
}

abstract class ContactRepository {
  Future<ContactConversation> open(String profileId);
  Future<ContactConversation> context(String id);
  Future<ContactInbox> inbox({ContactConversation? before});
  Future<ContactConversation> request({
    required String operationId,
    required String profileId,
    required String body,
  });
  Future<void> decide(String id, ContactState state);
  Future<List<TrainerMessage>> messages(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<void> send({
    required String operationId,
    required String contactId,
    required String body,
  });
  Future<void> markRead(String contactId, List<String> ids);
  Future<void> report(String id, DirectoryReportReason reason, String details);
}
