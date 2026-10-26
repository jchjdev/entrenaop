import 'package:flutter/material.dart';

import '../domain/ciq_connection.dart';

class CiqConnectionPage extends StatefulWidget {
  const CiqConnectionPage({
    super.key,
    required this.repository,
    required this.accountLabel,
  });
  final CiqConnectionRepository repository;
  final String accountLabel;
  @override
  State<CiqConnectionPage> createState() => _CiqConnectionPageState();
}

class _CiqConnectionPageState extends State<CiqConnectionPage> {
  final _code = TextEditingController();
  CiqAccount? _account;
  CiqPairReview? _review;
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } on CiqException catch (error) {
      if (mounted) {
        setState(() {
          _review = null;
          _message = ciqProblemMessage(error.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'No se pudo completar la operación. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
    final result = await widget.repository.load();
    if (mounted) setState(() => _account = result);
  });
  Future<void> _inspect() => _run(() async {
    final result = await widget.repository.review(_code.text);
    if (mounted) setState(() => _review = result);
  });
  Future<void> _approve() => _run(() async {
    final review = _review;
    if (review == null) return;
    await widget.repository.approve(_code.text, review.id);
    final account = await widget.repository.load();
    if (mounted) {
      setState(() {
        _account = account;
        _review = null;
        _code.clear();
        _message = 'Reloj vinculado. Vuelve a EntrenaOP en el reloj para actualizar tus sesiones.';
      });
    }
  });
  Future<void> _revoke(CiqLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar acceso del reloj'),
        content: const Text(
          'No podrá descargar más entrenamientos. Las copias ya guardadas pueden seguir disponibles en la biblioteca nativa del reloj.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirar acceso'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(() async {
      await widget.repository.revoke(link.id);
      final account = await widget.repository.load();
      if (mounted) setState(() => _account = account);
    });
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EntrenaOP en el reloj')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.accountLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Abre EntrenaOP en tu Garmin. Introduce el código de ocho caracteres que muestra el reloj y revisa la vinculación antes de confirmarla.',
        ),
        const SizedBox(height: 12),
        const Text(
          'El reloj recibirá tus sesiones compatibles de fuerza de los próximos 14 días y de ayer. Se actualizan al abrir la app del reloj; Actualizar permite forzar una nueva comprobación.',
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!, key: const Key('ciq-message')),
          ),
        if (_account?.allowed == false)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sin Pro ni un servicio de entrenador vigente no puedes vincular, descargar ni sincronizar entrenamientos con Garmin. Puedes retirar el acceso de tus relojes existentes.',
            ),
          ),
        if (_account?.allowed == true) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            maxLength: 9,
            autocorrect: false,
            onChanged: (_) => setState(() => _review = null),
            decoration: const InputDecoration(
              labelText: 'Código del reloj',
              hintText: 'ABCD-EF23',
            ),
          ),
          OutlinedButton(
            onPressed: _busy || _code.text.trim().isEmpty ? null : _inspect,
            child: const Text('Revisar vinculación'),
          ),
          if (_review case final review?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.device,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Cuenta: ${widget.accountLabel}'),
                    const Text(
                      'Autorizarás descargas de tus entrenamientos durante 90 días. Puedes retirar el permiso aquí en cualquier momento. Confirma solo el código que estás viendo en tu propio reloj.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : _approve,
                      child: const Text('Vincular este reloj'),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        Text(
          'Relojes vinculados',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_account?.links.isEmpty == true)
          const Text('Todavía no has vinculado ningún reloj.'),
        for (final link in _account?.links ?? <CiqLink>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.watch),
            title: Text('Garmin · ${_date(link.createdAt)}'),
            subtitle: Text(
              link.revoked
                  ? 'Acceso retirado'
                  : link.validUntil.isBefore(DateTime.now())
                  ? 'Vinculación caducada'
                  : 'Válido hasta ${_date(link.validUntil)}',
            ),
            trailing: link.revoked
                ? null
                : TextButton(
                    onPressed: _busy ? null : () => _revoke(link),
                    child: const Text('Retirar acceso'),
                  ),
          ),
        TextButton.icon(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar estado'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Esta vinculación permite descargar FIT en la app complementaria. La conexión con Garmin Connect para enviar por la vía habitual y recibir actividades se gestiona por separado.',
        ),
      ],
    ),
  );
}

String ciqProblemMessage(String code) => switch (code) {
  'invalid_code' || 'pair_expired' =>
    'El código no está disponible o ha caducado. Solicita otro desde el reloj.',
  'account_changed' ||
  'unauthorized' => 'Tu sesión ha cambiado. Vuelve a abrir esta pantalla.',
  'access_required' => 'Necesitas Pro o un servicio de entrenador vigente.',
  'rate_limited' =>
    'Has realizado varios intentos. Espera un minuto antes de volver a probar.',
  'device_limit' =>
    'Ya tienes cinco relojes activos. Retira uno antes de vincular otro.',
  _ => 'No se pudo completar la operación. Actualiza el estado antes de volver a probar.',
};
