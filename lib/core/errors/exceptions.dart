// Excepción para errores del servidor o de Supabase
class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class EmailConfirmationException extends ServerException {
  final String email;
  const EmailConfirmationException(this.email)
    : super('Confirma tu correo antes de entrar.');
}

class AuthLinkException extends ServerException {
  const AuthLinkException()
    : super(
        'El enlace ha caducado, ya se ha usado o no corresponde a este dispositivo. Solicita uno nuevo y ábrelo donde lo pediste.',
      );
}

// Excepción para errores de caché local
class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}
