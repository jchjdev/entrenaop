/// Ajustes por cuenta. Los horarios se interpretan en la zona IANA elegida,
/// también cuando cambia el horario de verano o el dispositivo viaja.
class NoticePreferences {
  const NoticePreferences({
    this.revision = 0,
    this.reminderMode = 'off',
    this.reminderMinute = 540,
    this.timezone = 'Europe/Madrid',
    this.quietEnabled = true,
    this.quietStart = 1320,
    this.quietEnd = 480,
  });
  final int revision, reminderMinute, quietStart, quietEnd;
  final String reminderMode, timezone;
  final bool quietEnabled;

  factory NoticePreferences.fromJson(Map value) => NoticePreferences(
    revision: value['revision'] as int,
    reminderMode: value['reminder_mode'] as String,
    reminderMinute: value['reminder_minute'] as int,
    timezone: value['timezone'] as String,
    quietEnabled: value['quiet_enabled'] as bool,
    quietStart: value['quiet_start'] as int,
    quietEnd: value['quiet_end'] as int,
  );

  NoticePreferences copyWith({
    int? revision,
    int? reminderMinute,
    int? quietStart,
    int? quietEnd,
    String? reminderMode,
    String? timezone,
    bool? quietEnabled,
  }) => NoticePreferences(
    revision: revision ?? this.revision,
    reminderMode: reminderMode ?? this.reminderMode,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    timezone: timezone ?? this.timezone,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );

  String? get validationError {
    if (!const ['off', 'sameDay', 'previousDay'].contains(reminderMode) ||
        [reminderMinute, quietStart, quietEnd].any((v) => v < 0 || v > 1439) ||
        timezone.isEmpty) {
      return 'Revisa los ajustes de los avisos.';
    }
    if (!quietEnabled) return null;
    if (quietStart == quietEnd) {
      return 'El inicio y el final del descanso deben ser distintos.';
    }
    final inQuiet = quietStart < quietEnd
        ? reminderMinute >= quietStart && reminderMinute < quietEnd
        : reminderMinute >= quietStart || reminderMinute < quietEnd;
    return reminderMode != 'off' && inQuiet
        ? 'Elige una hora fuera del horario de descanso.'
        : null;
  }
}
