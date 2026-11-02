import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Información de la versión de pruebas; no sustituye condiciones de venta.
class ProfileLegalPage extends StatelessWidget {
  const ProfileLegalPage({
    required this.privacy,
    required this.contactEmail,
    super.key,
  });
  final bool privacy;
  final String contactEmail;

  @override
  Widget build(BuildContext context) {
    final sections = privacy
        ? const [
            (
              'Tu cuenta y tus entrenamientos',
              'EntrenaOP utiliza tus datos de cuenta, perfil, marcas, disponibilidad y resultados para ofrecerte las funciones que utilizas. La información que compartes con un preparador se utiliza en el seguimiento de esa relación.',
            ),
            (
              'Dispositivos y conexiones',
              'Las conexiones con servicios y relojes son opcionales. Consulta sus permisos y su estado en Dispositivos y conexiones. Desconectar un servicio y eliminar los datos ya guardados son acciones distintas.',
            ),
            (
              'Avisos y compras',
              'Los avisos usan las preferencias y los permisos de tu dispositivo. Las pruebas de Pro verifican el acceso con el proveedor; la app no recoge los datos de tu tarjeta bancaria.',
            ),
            (
              'Cuando pides ayuda',
              'El mensaje se prepara en tu aplicación de correo para que lo revises antes de enviarlo. Los datos de versión son opcionales; no se adjuntan automáticamente entrenamientos, conversaciones ni credenciales.',
            ),
            (
              'Tus datos y tu cuenta',
              'Puedes contactar con EntrenaOP para consultar el tratamiento de tus datos o solicitar el ejercicio de tus derechos. Cerrar sesión no elimina la cuenta ni el historial. La eliminación definitiva desde la app todavía está pendiente de completar.',
            ),
          ]
        : const [
            (
              'Uso personal y seguimiento',
              'EntrenaOP reúne preparación, sesiones, Programas y seguimiento con un preparador. La preparación adaptativa y los Programas tienen recorridos distintos. Consulta lo pautado antes de comenzar y registra los resultados que hayas realizado.',
            ),
            (
              'Tu cuenta',
              'Utiliza tus propios datos y conserva tus credenciales. Los accesos personales y profesionales dependen de la cuenta y de los servicios habilitados.',
            ),
            (
              'Free, Pro y preparador',
              'Las funciones disponibles se indican en la app. Pro y el servicio de un preparador son accesos independientes. Perder Pro conserva la consulta del plan y el historial; iniciar nuevas sesiones adaptativas requiere Pro vigente. Una sesión ya abierta puede finalizarse.',
            ),
            (
              'Versión de pruebas',
              'Esta versión permite probar las funciones disponibles. Las compras de prueba se identifican como tales y no generan cobros reales. Las condiciones de contratación y las ofertas definitivas se publicarán antes de habilitar ventas.',
            ),
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text(privacy ? 'Privacidad' : 'Condiciones de uso'),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      privacy ? 'Privacidad en EntrenaOP' : 'Uso de EntrenaOP',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Información de la versión de pruebas · 2 de noviembre de 2026',
                    ),
                    const SizedBox(height: 20),
                    for (final (title, body) in sections) ...[
                      EntrenaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(body),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    EntrenaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Equipo de ayuda de EntrenaOP'),
                          const SizedBox(height: 8),
                          SelectableText(contactEmail),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
