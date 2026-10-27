import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_rpc.dart';

String trainerMessageOperationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class TrainerMessage {
  TrainerMessage.fromJson(Map<String, dynamic> row, String userId)
    : id = row['id'] as String,
      body = row['body'] as String,
      mine = row['sender_id'] == userId,
      createdAt = DateTime.parse(row['created_at'] as String),
      assignmentId = row['assignment_id'] as String?;
  final String id, body;
  final bool mine;
  final DateTime createdAt;
  final String? assignmentId;
}

class TrainerConversationContext {
  TrainerConversationContext.fromJson(Map<String, dynamic> row)
    : name = row['name'] as String,
      canSend = row['can_send'] == true;
  final String name;
  final bool canSend;
}

abstract class TrainerMessageRepository {
  Future<TrainerConversationContext> context(String relationId);
  Future<List<TrainerMessage>> list(
    String relationId, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<void> send({
    required String operationId,
    required String relationId,
    required String body,
    String? assignmentId,
  });
}

class SupabaseTrainerMessageRepository implements TrainerMessageRepository {
  const SupabaseTrainerMessageRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _identity() {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    _identity();
    try {
      final result = await authenticatedTrainerRpc(
        client,
        userId,
        name,
        params: params,
      );
      _identity();
      return result;
    } catch (_) {
      _identity();
      rethrow;
    }
  }

  Future<TrainerMessageInbox> inbox() async => TrainerMessageInbox.fromJson(
    Map<String, dynamic>.from(
      await _rpc('get_trainer_message_inbox', {'p_expected_owner': userId})
          as Map,
    ),
  );

  Future<void> markRead(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    await _rpc('read_trainer_messages', {
      'p_expected_owner': userId,
      'p_message_ids': messageIds,
    });
  }

  @override
  Future<TrainerConversationContext> context(String relationId) async =>
      TrainerConversationContext.fromJson(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_conversation', {'p_relation_id': relationId})
              as Map,
        ),
      );
  @override
  Future<List<TrainerMessage>> list(
    String relationId, {
    DateTime? beforeAt,
    String? beforeId,
  }) async =>
      (await _rpc('list_trainer_messages', {
            'p_relation_id': relationId,
            'p_before_at': beforeAt?.toUtc().toIso8601String(),
            'p_before_id': beforeId,
          }) as List)
          .map(
            (row) => TrainerMessage.fromJson(
              Map<String, dynamic>.from(row as Map),
              userId,
            ),
          )
          .toList();
  @override
  Future<void> send({
    required String operationId,
    required String relationId,
    required String body,
    String? assignmentId,
  }) async {
    if (body.trim().isEmpty || body.trim().length > 4000) {
      throw const FormatException(
        'Escribe un mensaje de hasta 4.000 caracteres.',
      );
    }
    await _rpc('send_trainer_message', {
      'p_id': operationId,
      'p_relation_id': relationId,
      'p_body': body.trim(),
      'p_assignment_id': assignmentId,
    });
  }
}

/// Resumen sin cuerpos privados; la conversación conserva su autorización propia.
class TrainerMessageInbox {
  const TrainerMessageInbox({
    required this.totalUnread,
    required this.conversations,
  });
  factory TrainerMessageInbox.fromJson(Map<String, dynamic> json) =>
      TrainerMessageInbox(
        totalUnread: (json['total_unread'] as num).toInt(),
        conversations: (json['conversations'] as List)
            .map(
              (row) => TrainerUnreadConversation.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
      );
  final int totalUnread;
  final List<TrainerUnreadConversation> conversations;
}

class TrainerUnreadConversation {
  TrainerUnreadConversation.fromJson(Map<String, dynamic> json)
    : relationId = json['relation_id'] as String,
      clientName = json['client_name'] as String,
      unreadCount = (json['unread_count'] as num).toInt();
  final String relationId, clientName;
  final int unreadCount;
}
