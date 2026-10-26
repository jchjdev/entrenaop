import 'package:entrenaop/features/welcome/domain/entry_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final code = 'a' * 64;

  test('conserva la invitación al pasar por acceso y registro, y la consume una vez', () {
    final entry = EntryNavigation();
    String? redirect(
      String path, {
      bool authenticated = false,
      bool publicRoute = false,
    }) => entry.redirect(
      uri: Uri.parse(path),
      authenticated: authenticated,
      publicRoute: publicRoute,
      needsWelcome: true,
    );
    expect(redirect(invitationRoute(code)), '/');
    expect(redirect('/sign-up', publicRoute: true), isNull);
    expect(redirect('/confirm-email', publicRoute: true), isNull);
    expect(
      redirect('/', authenticated: true, publicRoute: true),
      invitationRoute(code),
    );
    expect(redirect('/', authenticated: true, publicRoute: true), '/welcome');
  });

  test('solo Inicio activa la bienvenida; herramientas, invitaciones y sesiones directas se respetan', () {
    final entry = EntryNavigation();
    for (final route in [
      '/tools',
      '/invite',
      '/plan/session/fixture',
      '/profile',
    ]) {
      expect(
        entry.redirect(
          uri: Uri.parse(route),
          authenticated: true,
          publicRoute: false,
          needsWelcome: true,
        ),
        isNull,
      );
    }
    expect(
      entry.redirect(
        uri: Uri.parse('/home'),
        authenticated: true,
        publicRoute: false,
        needsWelcome: true,
      ),
      '/welcome',
    );
    expect(
      entry.redirect(
        uri: Uri.parse('/home'),
        authenticated: true,
        publicRoute: false,
        needsWelcome: false,
      ),
      isNull,
    );
  });

  test(
    'parámetros externos no se convierten en un retorno tras iniciar sesión',
    () {
      final entry = EntryNavigation();
      entry.redirect(
        uri: Uri.parse('/tools?next=https://example.com'),
        authenticated: false,
        publicRoute: false,
        needsWelcome: true,
      );
      expect(
        entry.redirect(
          uri: Uri.parse('/?next=https://example.com'),
          authenticated: true,
          publicRoute: true,
          needsWelcome: false,
        ),
        '/home',
      );
    },
  );

  test(
    'admite códigos y enlaces con ruta normal o hash sin abrir sus URLs',
    () {
      for (final value in [
        code,
        '  $code  ',
        invitationRoute(code),
        'https://entrenaop.es/invite?code=$code',
        'https://entrenaop.es/#/invite#$code',
        'https://entrenaop.es/#/invite?code=$code',
      ]) {
        expect(trainerInvitationCode(value), code, reason: value);
      }
      for (final value in [
        'abc',
        'javascript:/invite?code=$code',
        'https://example.com/other?code=$code',
        '/invite#invalid',
        '/invite#%FF',
        'b' * 65,
      ]) {
        expect(trainerInvitationCode(value), isNull, reason: value);
      }
    },
  );
}
