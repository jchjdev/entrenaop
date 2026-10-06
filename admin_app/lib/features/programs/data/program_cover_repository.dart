import 'dart:math';

import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProgramCoverRepository implements ProgramCoverRepository {
  SupabaseProgramCoverRepository(this.client);
  final SupabaseClient client;
  static const bucket = 'program-covers-public';

  ProgramCover _parse(Map<String, dynamic> json) => ProgramCover(
    programId: json['program_id'] as String,
    cardPath: json['card_image_path'] as String?,
    headerPath: json['header_image_path'] as String?,
    cardUrl: _url(json['card_image_path'] as String?),
    headerUrl: _url(json['header_image_path'] as String?),
    focalX: (json['focal_x'] as num).toDouble(),
    focalY: (json['focal_y'] as num).toDouble(),
    headerFocalX: (json['header_focal_x'] as num?)?.toDouble(),
    headerFocalY: (json['header_focal_y'] as num?)?.toDouble(),
    revision: json['revision'] as int,
  );
  String? _url(String? path) =>
      path == null ? null : client.storage.from(bucket).getPublicUrl(path);

  @override
  Future<ProgramCover> load(String programId) async {
    final value = await client
        .from('preparation_program_covers')
        .select()
        .eq('program_id', programId)
        .maybeSingle();
    return value == null ? ProgramCover(programId: programId) : _parse(value);
  }

  @override
  Future<ProgramCover> save(
    ProgramCover current, {
    required double focalX,
    required double focalY,
    required double headerFocalX,
    required double headerFocalY,
    ProgramCoverUpload? upload,
    bool removeImage = false,
  }) async {
    if (!focalX.isFinite ||
        !focalY.isFinite ||
        focalX < 0 ||
        focalX > 1 ||
        focalY < 0 ||
        focalY > 1 ||
        !headerFocalX.isFinite ||
        !headerFocalY.isFinite ||
        headerFocalX < 0 ||
        headerFocalX > 1 ||
        headerFocalY < 0 ||
        headerFocalY > 1 ||
        (upload != null && removeImage)) {
      throw const FormatException('Portada no válida.');
    }
    var cardPath = removeImage ? null : current.cardPath;
    var headerPath = removeImage ? null : current.headerPath;
    final uploaded = <String>[];
    try {
      if (upload != null) {
        if (upload.card.isEmpty ||
            upload.header.isEmpty ||
            upload.card.length > 512 * 1024 ||
            upload.header.length > 512 * 1024) {
          throw const FormatException('La portada supera el límite permitido.');
        }
        final random = Random.secure();
        final version = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        final prefix = 'official/${current.programId}/$version';
        cardPath = '$prefix/card.jpg';
        headerPath = '$prefix/header.jpg';
        for (final entry in [
          (cardPath, upload.card),
          (headerPath, upload.header),
        ]) {
          await client.storage
              .from(bucket)
              .uploadBinary(
                entry.$1,
                entry.$2,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  cacheControl: '31536000',
                  upsert: false,
                ),
              );
          uploaded.add(entry.$1);
        }
      }
      final response = Map<String, dynamic>.from(
        await client.rpc(
          'set_admin_program_cover_v2',
          params: {
            'p_program_id': current.programId,
            'p_card_image_path': cardPath,
            'p_header_image_path': headerPath,
            'p_focal_x': focalX,
            'p_focal_y': focalY,
            'p_header_focal_x': headerFocalX,
            'p_header_focal_y': headerFocalY,
            'p_expected_revision': current.revision,
          },
        ) as Map,
      );
      final saved = _parse(Map<String, dynamic>.from(response['cover'] as Map));
      final previous =
          [response['previous_card_path'], response['previous_header_path']]
              .whereType<String>()
              .where((p) => p != cardPath && p != headerPath)
              .toList();
      await _cleanup(previous);
      return saved;
    } catch (error) {
      // Una respuesta perdida puede haber guardado la portada. RLS protege archivos vigentes.
      await _cleanup(uploaded);
      if (error is PostgrestException && error.code == '40001') {
        throw const ProgramCoverConflict();
      }
      rethrow;
    }
  }

  Future<void> _cleanup(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await client.storage.from(bucket).remove(paths);
    } catch (_) {
      /* Los huérfanos pueden limpiarse después; la portada guardada se conserva. */
    }
  }
}
