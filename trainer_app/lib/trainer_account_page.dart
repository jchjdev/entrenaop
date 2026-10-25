import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_security.dart';

class TrainerAccountPage extends StatefulWidget {
  const TrainerAccountPage({
    super.key,
    required this.email,
    required this.access,
    required this.security,
    required this.onSignOut,
  });
  final String email;
  final TrainerRepository access;
  final TrainerSecurity security;
  final Future<void> Function() onSignOut;
  @override
  State<TrainerAccountPage> createState() => _TrainerAccountPageState();
}

class _TrainerAccountPageState extends State<TrainerAccountPage> {
  late Future<({TrainerAccess access, bool assured})> _future = _load();
  bool _busy = false;
  String? _error;
  Future<({TrainerAccess access, bool assured})> _load() async => (
    access: await widget.access.access(),
    assured: await widget.security.assured(),
  );
  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cerrar la sesión. Reintenta.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cuenta profesional')),
    body: FutureBuilder<({TrainerAccess access, bool assured})>(
      future: _future,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ProfessionalSectionHeader(title: 'Mi cuenta', subtitle: widget.email),
          const SizedBox(height: 24),
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: const Text('No se pudo comprobar la cuenta. Reintentar'),
            ),
          if (snapshot.data case final account?)
            ProfessionalCatalogGrid(
              children: [
                EntrenaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acceso profesional',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(account.access.status),
                      Text(
                        '${account.access.activeClients}/${account.access.limit} plazas ocupadas',
                      ),
                      if (account.access.validUntil != null)
                        Text(
                          'Vigente hasta ${trainerDate(account.access.validUntil!)}',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'El acceso profesional y la suscripción personal Pro se gestionan por separado.',
                      ),
                    ],
                  ),
                ),
                EntrenaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seguridad',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        account.assured
                            ? 'Doble factor validado en esta sesión'
                            : 'Es necesario verificar el autenticador',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El autenticador pertenece a tu cuenta de EntrenaOP. Tus permisos dependen del portal y del servicio.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (_error != null) Text(_error!),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    ),
  );
}
