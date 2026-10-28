import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_invitation_link.dart';

void main() {
  final secret = List.filled(64, 'a').join();
  test('el enlace comparte fragmento, no query HTTP; abre la misma capacidad sin mezclar Auth', () {
    final share = TrainerInvitationLink.share(secret);
    expect(share.query, isEmpty);
    expect(share.path, '/');
    expect(TrainerInvitationLink.parse(share), secret);
    final app = TrainerInvitationLink.openApp(secret);
    expect(app.query, isEmpty);
    expect(app.host, 'trainer-invitation');
    expect(Uri.splitQueryString(app.fragment).containsKey('code'), false);
    expect(TrainerInvitationLink.parse(app), secret);
    expect(TrainerInvitationLink.fromInput('  $share  '), secret);
    expect(TrainerInvitationLink.fromInput(secret), secret);
  });
  test('rechaza hosts, credenciales, puertos, rutas y parámetros que no pertenecen a invitaciones', () {
    final own = TrainerInvitationLink.share(secret);
    final invalid = [
      own.replace(host: 'evil.invalid'),
      own.replace(scheme: 'http'),
      own.replace(userInfo: 'persona'),
      own.replace(port: 444),
      own.replace(path: '/otra'),
      own.replace(query: 'code=auth'),
      own.replace(fragment: '/invite?invitation=$secret&invitation=$secret'),
      own.replace(fragment: '/invite?invitation=$secret&code=auth'),
      Uri.parse('es.entrenaop://auth-callback/#access_token=private'),
      Uri.parse('es.entrenaop://trainer-invitation/other#invitation=$secret'),
      Uri.parse('https://trainer.entrenaop.es/#/invite?invitation=short'),
    ];
    for (final uri in invalid) {
      expect(TrainerInvitationLink.parse(uri), isNull, reason: uri.host);
    }
    expect(TrainerInvitationLink.fromInput('not an invitation'), isNull);
  });
  test(
    'destinatario permite alias pero evita campos vacíos y cabeceras de correo',
    () {
      expect(
        TrainerInvitationLink.validEmail('alumno+fuerza@example.es'),
        true,
      );
      for (final value in [
        '',
        'alumno',
        'a@b',
        'a b@c.es',
        'alumno@x.es\nBcc:ajeno@x.es',
      ]) {
        expect(TrainerInvitationLink.validEmail(value), false);
      }
    },
  );
}
