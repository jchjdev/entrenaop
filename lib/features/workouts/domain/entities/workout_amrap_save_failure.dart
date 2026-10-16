/// El adaptador traduce los errores remotos sin exponer SQL a la interfaz.
class WorkoutAmrapSaveFailure implements Exception {
  const WorkoutAmrapSaveFailure(this.message, {this.code});
  final String message;
  final String? code;
}
