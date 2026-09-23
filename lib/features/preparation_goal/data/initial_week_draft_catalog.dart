import 'dart:convert';

import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:flutter/services.dart';

/// Contenido deportivo en revisión. Nunca crea plantillas ni agenda oficial.
class InitialWeekDraftCatalog {
  const InitialWeekDraftCatalog._();

  static const assetPath = 'assets/programs/tropa/initial_week_draft_v1.json';

  static Future<InitialWeekDraft> load() async {
    final source = await rootBundle.loadString(assetPath);
    return InitialWeekDraft.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }
}

class InitialWeekDraft {
  const InitialWeekDraft({
    required this.version,
    required this.totalDays,
    required this.runningDays,
    required this.strengthDays,
    required this.intro,
    required this.cycleNote,
    required this.sessions,
  });

  final String version;
  final int totalDays;
  final int runningDays;
  final int strengthDays;
  final String intro;
  final String cycleNote;
  final List<InitialWeekDraftSession> sessions;

  factory InitialWeekDraft.fromJson(Map<String, dynamic> json) {
    if (json['programId'] != PreparationProgramIds.armedForcesTroopEntry ||
        json['status'] != 'draft') {
      throw const FormatException('Borrador de programa o estado no válido.');
    }
    final sessions = (json['sessions'] as List<dynamic>)
        .map(
          (item) =>
              InitialWeekDraftSession.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
    final totalDays = json['totalDays'] as int;
    final runningDays = json['runningDays'] as int;
    final strengthDays = json['strengthDays'] as int;
    if (totalDays < 1 ||
        sessions.length != totalDays ||
        runningDays < 0 ||
        strengthDays < 0 ||
        runningDays + strengthDays != totalDays ||
        sessions.where((item) => item.modality == 'running').length !=
            runningDays ||
        sessions.where((item) => item.modality == 'strength').length !=
            strengthDays ||
        sessions.map((item) => item.id).toSet().length != sessions.length) {
      throw const FormatException('Reparto semanal del borrador no válido.');
    }
    return InitialWeekDraft(
      version: _requiredText(json['version']),
      totalDays: totalDays,
      runningDays: runningDays,
      strengthDays: strengthDays,
      intro: _requiredText(json['intro']),
      cycleNote: _requiredText(json['cycleNote']),
      sessions: sessions,
    );
  }
}

class InitialWeekDraftSession {
  const InitialWeekDraftSession({
    required this.id,
    required this.dayLabel,
    required this.modality,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final String id;
  final String dayLabel;
  final String modality;
  final String title;
  final String subtitle;
  final List<String> details;

  factory InitialWeekDraftSession.fromJson(Map<String, dynamic> json) {
    final modality = json['modality'];
    if (modality != 'running' && modality != 'strength') {
      throw const FormatException('Modalidad del borrador no válida.');
    }
    final details = (json['details'] as List<dynamic>)
        .map(_requiredText)
        .toList(growable: false);
    if (details.isEmpty) {
      throw const FormatException('Sesión sin contenido.');
    }
    return InitialWeekDraftSession(
      id: _requiredText(json['id']),
      dayLabel: _requiredText(json['dayLabel']),
      modality: modality as String,
      title: _requiredText(json['title']),
      subtitle: _requiredText(json['subtitle']),
      details: details,
    );
  }
}

String _requiredText(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Falta texto en el borrador.');
  }
  return value;
}
