import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:trainer_access/trainer_security.dart';
import 'package:url_launcher/url_launcher.dart';

typedef SubscriptionJson = Map<String, dynamic>;

abstract class TrainerSubscriptionRepository {
  Future<SubscriptionJson> status();
  Future<bool> assured();
  Future<SubscriptionJson> act(String action, {String? offerId});
}

class SupabaseTrainerSubscriptionRepository
    implements TrainerSubscriptionRepository {
  const SupabaseTrainerSubscriptionRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;
  void _identity() {
    if (client.auth.currentUser?.id != owner) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  @override
  Future<SubscriptionJson> status() async {
    _identity();
    final value = await authenticatedTrainerRpc(
      client,
      owner,
      'get_my_trainer_subscription',
      params: {'p_expected_owner': owner},
    );
    _identity();
    return SubscriptionJson.from(value as Map);
  }

  @override
  Future<bool> assured() => SupabaseTrainerSecurity(client, owner).assured();
  @override
  Future<SubscriptionJson> act(String action, {String? offerId}) async {
    _identity();
    final result = await client.functions.invoke(
      'trainer-commerce',
      body: {'action': action, 'offer_id': ?offerId},
    );
    _identity();
    if (result.status != 200) {
      throw StateError('La contratación no está disponible.');
    }
    return SubscriptionJson.from(result.data as Map);
  }
}

Uri trainerPaymentDestination(Object? value, {required bool portal}) {
  final uri = Uri.tryParse(value is String ? value : '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != (portal ? 'billing.stripe.com' : 'checkout.stripe.com') ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort) {
    throw StateError('Destino de pago inválido.');
  }
  return uri;
}

class TrainerSubscriptionPage extends StatefulWidget {
  const TrainerSubscriptionPage({
    super.key,
    required this.repository,
    this.openPayment,
    this.returnedFromCheckout = false,
  });
  final TrainerSubscriptionRepository repository;
  final Future<bool> Function(Uri uri)? openPayment;
  final bool returnedFromCheckout;
  @override
  State<TrainerSubscriptionPage> createState() =>
      _TrainerSubscriptionPageState();
}

class _TrainerSubscriptionPageState extends State<TrainerSubscriptionPage> {
  SubscriptionJson? _data;
  bool _busy = false;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _load();
    if (mounted &&
        widget.returnedFromCheckout &&
        _data?['subscription'] != null) {
      // Volver de Stripe solicita conciliación; nunca concede acceso por la URL.
      await _act('refresh');
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.repository.status();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo comprobar la suscripción. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(String action, {String? offerId}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final assured = await widget.repository.assured();
      if (!mounted) return;
      if (!assured) {
        context.go('/security?next=subscription');
        return;
      }
      final result = await widget.repository.act(action, offerId: offerId);
      if (!mounted) return;
      if (result['url'] != null) {
        final uri = trainerPaymentDestination(
          result['url'],
          portal: action == 'portal',
        );
        final opened =
            await (widget.openPayment?.call(uri) ??
                launchUrl(uri, webOnlyWindowName: '_self'));
        if (!opened) throw StateError('No se abrió Stripe.');
      } else {
        final data = await widget.repository.status();
        if (mounted) {
          setState(() {
            _data = data;
            _notice = result['confirmed'] == true
                ? 'Pago confirmado por el servidor. Tu acceso profesional está preparado.'
                : 'Estado actualizado. El acceso solo se activa cuando el servidor confirma el pago.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo completar la comprobación. Puedes reintentar sin crear otro pedido.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _data?['subscription'] as Map?;
    final offers = (_data?['offers'] as List?) ?? const [];
    final state = sub?['state'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripción profesional'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ProfessionalSectionHeader(
            title: 'Tu espacio de preparador',
            subtitle:
                'Contratación en pruebas · sin movimientos reales de dinero',
          ),
          const SizedBox(height: 20),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_notice != null) Text(_notice!),
          if (_data != null && _data!['enabled'] != true)
            const EntrenaCard(
              child: Text(
                'Estamos preparando la contratación de prueba. La cuenta y los accesos concedidos por EntrenaOP se conservan.',
              ),
            ),
          if (sub != null) ...[
            EntrenaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (state) {
                    'active' => 'Suscripción activa',
                    'past_due' => 'Pago pendiente de resolver',
                    'canceled' => 'Suscripción cancelada',
                    'expired' => 'Intento de contratación caducado',
                    _ => 'Contratación pendiente',
                  }, style: Theme.of(context).textTheme.titleLarge),
                  if (sub['paid_until'] != null)
                    Text('Periodo pagado hasta ${_date(sub['paid_until'])}'),
                  if (sub['cancel_at_period_end'] == true)
                    const Text(
                      'La cancelación está programada para el final del periodo pagado.',
                    ),
                  const Text(
                    'Los accesos de regalo de ADMIN se conservan por separado.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : () => _act('refresh'),
                        child: const Text('Comprobar pago'),
                      ),
                      if (['active', 'past_due', 'canceled'].contains(state))
                        OutlinedButton(
                          onPressed: _busy ? null : () => _act('portal'),
                          child: const Text('Gestionar suscripción'),
                        ),
                      if (state == 'active')
                        FilledButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Entrar al panel'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (sub == null ||
              ['prepared', 'open', 'expired', 'canceled'].contains(state))
            ProfessionalCatalogGrid(
              children: [
                for (final offer in offers)
                  EntrenaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(offer['amount'] / 100).toStringAsFixed(2)} € / ${offer['interval'] == 'year' ? 'año' : 'mes'}',
                        ),
                        Text('${offer['capacity']} plazas de alumnos'),
                        const Text(
                          'Importe simulado para probar el recorrido. No es una tarifa comercial.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy || _data?['enabled'] != true
                              ? null
                              : () => _act(
                                  'checkout',
                                  offerId: offer['id'] as String,
                                ),
                          child: Text(
                            state == 'open'
                                ? 'Continuar pago de prueba'
                                : 'Contratar en pruebas',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          const Text(
            'Esta suscripción es para tus herramientas profesionales. Pro personal y el pago de tus alumnos por tus servicios se gestionan por separado.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('Actualizar estado'),
            ),
          ),
        ],
      ),
    );
  }

  String _date(Object value) {
    final date = DateTime.tryParse(value.toString())?.toLocal();
    return date == null
        ? 'pendiente de comprobar'
        : '${date.day}/${date.month}/${date.year}';
  }
}
