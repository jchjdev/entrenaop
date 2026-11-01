import 'device_activity_summary.dart';

/// Consulta privada del titular. No asocia actividades ni completa pautas.
abstract interface class DeviceActivityInboxRepository {
  Future<List<DeviceActivitySummary>> load();
}
