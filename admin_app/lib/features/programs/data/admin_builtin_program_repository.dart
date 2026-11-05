import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AdminBuiltinProgramRepository {
  static bool supports(String id) =>
      id == 'armed_forces_troop_entry' || id == 'fas_periodic_assessment';
  Future<AdminBuiltinProgramData> load(String programId);
}

class AdminBuiltinProgramData {
  const AdminBuiltinProgramData({
    required this.programId,
    required this.version,
    required this.name,
    required this.sourceUrl,
    required this.effectiveFrom,
    required this.standards,
    required this.objectives,
  });
  final String programId, version, name, sourceUrl, effectiveFrom;
  final List<AdminBuiltinStandard> standards;
  final List<Map<String, dynamic>> objectives;
  bool get isFas => programId == 'fas_periodic_assessment';
}

class AdminBuiltinStandard {
  const AdminBuiltinStandard({
    required this.testId,
    required this.name,
    required this.unit,
    required this.direction,
    required this.category,
    required this.group,
    required this.threshold,
  });
  final String testId, name, unit, direction, category, group;
  final int threshold;

  factory AdminBuiltinStandard.fromJson(
    Map<String, dynamic> row, {
    required bool fas,
  }) {
    final test = Map<String, dynamic>.from(
      row['physical_test_definitions'] as Map,
    );
    final unit = test['unit'] as String;
    final direction = test['better_direction'] as String;
    if (!['milliseconds', 'repetitions'].contains(unit) ||
        !['higher', 'lower'].contains(direction)) {
      throw const FormatException(
        'Unidad o dirección de catálogo no compatible.',
      );
    }
    return AdminBuiltinStandard(
      testId: row['test_id'] as String,
      name: test['name'] as String,
      unit: unit,
      direction: direction,
      category: row['category'] as String,
      group: row[fas ? 'age_band' : 'milestone'] as String,
      threshold: (row['threshold'] as num).toInt(),
    );
  }

  String get formattedThreshold {
    if (unit == 'repetitions') return '$threshold repeticiones';
    // Los catálogos históricos guardan milisegundos, no segundos decimales.
    final minutes = threshold ~/ 60000;
    final seconds = (threshold ~/ 1000) % 60;
    final millis = threshold % 1000;
    final fraction = millis == 0
        ? ''
        : '.${millis.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
    if (minutes == 0) return '$seconds$fraction s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}$fraction min';
  }
}

class SupabaseAdminBuiltinProgramRepository
    implements AdminBuiltinProgramRepository {
  const SupabaseAdminBuiltinProgramRepository(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> _all(
    Future<List<Map<String, dynamic>>> Function(int, int) page,
  ) async {
    const size = 500;
    final result = <Map<String, dynamic>>[];
    for (var from = 0; ; from += size) {
      final rows = await page(from, from + size - 1);
      result.addAll(rows);
      if (rows.length < size) return result;
    }
  }

  @override
  Future<AdminBuiltinProgramData> load(String programId) async {
    if (!AdminBuiltinProgramRepository.supports(programId)) {
      throw ArgumentError.value(programId, 'programId');
    }
    final link = await client
        .from('preparation_program_catalogs')
        .select(
          'catalog_version,assessment_catalogs(version,name,source_url,effective_from)',
        )
        .eq('program_id', programId)
        .eq('is_current', true)
        .single();
    final catalog = Map<String, dynamic>.from(
      link['assessment_catalogs'] as Map,
    );
    final version = link['catalog_version'] as String;
    final fas = programId == 'fas_periodic_assessment';
    final group = fas ? 'age_band' : 'milestone';
    final standards = await _all(
      (from, to) async => await client
          .from(fas ? 'fas_periodic_standards' : 'assessment_standards')
          .select(
            'test_id,category,$group,threshold,physical_test_definitions(id,name,unit,better_direction)',
          )
          .eq('catalog_version', version)
          .order('test_id', ascending: true)
          .order('category', ascending: true)
          .order(group, ascending: true)
          .range(from, to),
    );
    if (standards.isEmpty) {
      throw StateError('El catálogo vinculado no devuelve sus mínimos.');
    }
    final objectives = await _all(
      (from, to) async => await client
          .from('performance_legacy_objectives')
          .select(
            'objective_key,name,profile_code,profile_version,measurement,protocol_key,protocol_version,parameters,instructions,max_age_exclusive',
          )
          .eq('program_id', programId)
          .order('objective_key', ascending: true)
          .range(from, to),
    );
    return AdminBuiltinProgramData(
      programId: programId,
      version: version,
      name: catalog['name'] as String,
      sourceUrl: catalog['source_url'] as String,
      effectiveFrom: catalog['effective_from'] as String,
      standards: standards
          .map((r) => AdminBuiltinStandard.fromJson(r, fas: fas))
          .toList(),
      objectives: objectives,
    );
  }
}
