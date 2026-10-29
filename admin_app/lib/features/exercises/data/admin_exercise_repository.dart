import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:workout_core/workout_template.dart';

import 'admin_exercise_trash_repository.dart';

class AdminCatalogExercise {
  const AdminCatalogExercise({
    required this.id,
    required this.name,
    required this.muscleGroups,
    required this.equipment,
    required this.difficulty,
    required this.exerciseType,
    this.description,
    this.videoUrl,
    this.imagePath,
    this.imageUrl,
    this.trainingProfile,
    this.isPublic = true,
  });

  final String id;
  final String name;
  final String? description;
  final String? videoUrl;
  final String? imagePath;
  final String? imageUrl;
  final List<String> muscleGroups;
  final List<String> equipment;
  final String difficulty;
  final String exerciseType;
  final StrengthExerciseDefinition? trainingProfile;
  final bool isPublic;

  ExerciseDraft toDraft() => ExerciseDraft(
    name: name,
    description: description,
    videoUrl: videoUrl,
    muscleGroups: muscleGroups,
    equipment: equipment,
    difficulty: difficulty,
    exerciseType: exerciseType,
  );

  factory AdminCatalogExercise.fromJson(Map<String, dynamic> json) =>
      AdminCatalogExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        isPublic: json['is_public'] != false,
        description: json['description'] as String?,
        videoUrl: json['video_url'] as String?,
        imagePath: json['image_path'] as String?,
        muscleGroups: (json['muscle_groups'] as List? ?? const [])
            .cast<String>(),
        equipment: (json['equipment'] as List? ?? const []).cast<String>(),
        difficulty: json['difficulty'] as String,
        exerciseType: json['exercise_type'] as String,
        trainingProfile: json['training_profile'] == null
            ? null
            : StrengthExerciseCatalogCodec.decodeDefinition(
                Map<String, dynamic>.from(
                  json['training_profile']['definition'] as Map,
                ),
                definitionVersion:
                    json['training_profile']['definition_version'] as int,
              ),
      );
}

abstract class AdminExerciseRepository {
  Future<List<AdminCatalogExercise>> listOfficial();
  Future<String> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  });
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  });
}

class SupabaseAdminExerciseRepository
    implements AdminExerciseRepository, AdminExerciseTrashRepository {
  const SupabaseAdminExerciseRepository(
    this._client, {
    this.ownerId,
    this.processMediaCleanup,
  });

  final SupabaseClient _client;
  final String? ownerId;
  final Future<void> Function()? processMediaCleanup;

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async {
    final rows = await _client
        .from('exercises')
        .select(
          'id,name,description,video_url,image_path,muscle_groups,equipment,difficulty,exercise_type,is_public,'
          'training_profile:exercise_training_profiles!exercise_training_profile_fk(definition_version,definition)',
        )
        .eq('origin', 'system')
        .isFilter('trashed_at', null)
        .order('name');
    return rows.where((row) => row['id'] != runningExerciseId).map((row) {
      final exercise = AdminCatalogExercise.fromJson(row);
      final path = exercise.imagePath;
      return AdminCatalogExercise(
        id: exercise.id,
        name: exercise.name,
        description: exercise.description,
        videoUrl: exercise.videoUrl,
        imagePath: path,
        imageUrl: path == null
            ? null
            : _client.storage.from(_publicBucket).getPublicUrl(path),
        muscleGroups: exercise.muscleGroups,
        equipment: exercise.equipment,
        difficulty: exercise.difficulty,
        exerciseType: exercise.exerciseType,
        trainingProfile: exercise.trainingProfile,
        isPublic: exercise.isPublic,
      );
    }).toList();
  }

  Future<dynamic> _trashRpc(String name, [Map<String, dynamic>? params]) async {
    final expectedOwner = ownerId ?? _client.auth.currentUser?.id;
    if (expectedOwner == null) {
      throw StateError('Se necesita una sesión válida.');
    }
    try {
      return await authenticatedTrainerRpc(
        _client,
        expectedOwner,
        name,
        params: params,
      );
    } on PostgrestException catch (error) {
      if (error.code == 'P0001' || error.code == '22023') {
        throw FormatException(error.message);
      }
      if (error.code == '40001') {
        throw const FormatException(
          'La papelera ha cambiado. Actualiza antes de reintentar.',
        );
      }
      if (error.code == '42501' || error.code == '28000') {
        throw const FormatException(
          'La cuenta no tiene permiso para completar esta operación. Comprueba el acceso y el doble factor.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<AdminExerciseTrashEntry>> listExerciseTrash({
    AdminExerciseTrashEntry? before,
    int limit = 50,
  }) async =>
      ((await _trashRpc('list_admin_exercise_trash', {
            'p_limit': limit,
            'p_before_at': before?.trashedAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          })) as List)
          .map(
            (row) => AdminExerciseTrashEntry.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

  @override
  Future<void> trashExercise(String id, {required String operationId}) async {
    final receipt = await _trashRpc('trash_admin_exercise', {
      'p_id': id,
      'p_operation_id': operationId,
    });
    _confirmedReceipt(receipt, id, 'trashed');
  }

  @override
  Future<void> restoreExercise(
    AdminExerciseTrashEntry entry, {
    required String operationId,
  }) async {
    await _mutateExerciseTrash(
      'restore_admin_exercise',
      entry,
      operationId,
      'restored',
    );
  }

  @override
  Future<void> purgeExercise(
    AdminExerciseTrashEntry entry, {
    required String operationId,
  }) async {
    await _mutateExerciseTrash(
      'purge_admin_exercise',
      entry,
      operationId,
      'purged',
    );
    await _runMediaCleanup();
  }

  Future<void> _mutateExerciseTrash(
    String name,
    AdminExerciseTrashEntry entry,
    String operationId,
    String status,
  ) async {
    final receipt = await _trashRpc(name, {
      'p_id': entry.id,
      'p_operation_id': operationId,
      'p_trashed_at': entry.trashedAt.toUtc().toIso8601String(),
    });
    _confirmedReceipt(receipt, entry.id, status);
  }

  Map _confirmedReceipt(Object? receipt, String id, String status) {
    if (receipt is! Map ||
        receipt['id'] != id ||
        receipt['kind'] != 'exercise' ||
        receipt['status'] != status ||
        (status == 'trashed' &&
            (receipt['trashed_at'] is! String ||
                DateTime.tryParse(receipt['trashed_at'] as String) == null))) {
      // HTTP 200 sin recibo coherente no confirma la escritura. Mantiene UUID
      // para consultar/reintentar sin declarar un borrado que no conocemos.
      throw StateError('No se pudo confirmar la operación del ejercicio.');
    }
    return receipt;
  }

  @override
  Future<String> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    final id = await _client.rpc(
      'create_admin_exercise',
      params: _params(value),
    );
    if (image == null) return id as String;
    String? uploadedPath;
    try {
      uploadedPath = await _upload(id as String, image);
      await _client.rpc(
        'set_admin_exercise_image',
        params: {'p_exercise_id': id, 'p_image_path': uploadedPath},
      );
    } catch (_) {
      try {
        await _discardFailedCreation(id as String);
      } catch (_) {
        // Una respuesta incierta no autoriza un DELETE ni a retirar medios.
        // Lo que haya llegado a papelera conserva sus referencias y permisos.
      }
      rethrow;
    }
    return id;
  }

  Future<void> _discardFailedCreation(String id) async {
    final moved = _confirmedReceipt(
      await _cleanupRpc('trash_admin_exercise', {
        'p_id': id,
        'p_operation_id': _newOperationId(),
      }),
      id,
      'trashed',
    );
    final purged = await _cleanupRpc('purge_admin_exercise', {
      'p_id': id,
      'p_operation_id': _newOperationId(),
      'p_trashed_at': moved['trashed_at'],
    });
    _confirmedReceipt(purged, id, 'purged');
    // El proveedor y la reserva los confirma el trabajador de la cola. Nunca
    // se adelanta aquí el borrado externo a su acuse de recibo.
    await _runMediaCleanup();
  }

  Future<dynamic> _cleanupRpc(String name, Map<String, dynamic> params) async {
    try {
      return await _trashRpc(name, params);
    } on FormatException {
      rethrow;
    } on StateError {
      rethrow;
    } catch (_) {
      // Un único reintento con el mismo recibo confirma respuestas perdidas.
      return _trashRpc(name, params);
    }
  }

  @override
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    final value = ExerciseDraftValidator.normalizeAndValidate(draft);
    await _client.rpc(
      'update_admin_exercise',
      params: {'p_exercise_id': id, ..._params(value)},
    );
    if (image != null) {
      final path = await _upload(id, image);
      await _client.rpc(
        'set_admin_exercise_image',
        params: {'p_exercise_id': id, 'p_image_path': path},
      );
    } else if (removeImage) {
      await _client.rpc(
        'set_admin_exercise_image',
        params: {'p_exercise_id': id, 'p_image_path': null},
      );
    }
    await _runMediaCleanup();
  }

  Future<String> _upload(String exerciseId, ExerciseImageUpload image) async {
    final path =
        'official/$exerciseId/'
        '${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    await _client.storage
        .from(_publicBucket)
        .uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            contentType: image.contentType,
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _runMediaCleanup() async {
    try {
      await processMediaCleanup?.call().timeout(const Duration(seconds: 5));
    } catch (_) {
      // La escritura ya está confirmada; Cron conserva y reintenta la cola.
    }
  }
}

const _publicBucket = 'exercise-images-public';

String _newOperationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, Object?> _params(ExerciseDraft draft) => {
  'p_name': draft.name,
  'p_description': draft.description,
  'p_video_url': draft.videoUrl,
  'p_muscle_groups': draft.muscleGroups,
  'p_equipment': draft.equipment,
  'p_difficulty': draft.difficulty,
  'p_exercise_type': draft.exerciseType,
};
