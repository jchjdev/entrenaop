import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pro_offer.dart';
import '../widgets/pro_brand_title.dart';
import '../widgets/pro_access_widgets.dart';
import '../../domain/pro_access.dart';

class ProOfferPage extends StatefulWidget {
  const ProOfferPage({
    this.offerContext = const ProOfferContext(),
    this.loadAccess,
    super.key,
  });
  final ProOfferContext offerContext;
  final LoadProAccess? loadAccess;

  @override
  State<ProOfferPage> createState() => _ProOfferPageState();
}

class _ProOfferPageState extends State<ProOfferPage> {
  ProBillingPeriod _period = ProBillingPeriod.annual;

  @override
  Widget build(BuildContext context) => _ProScaffold(
    title: 'EntrenaOP Pro',
    brandTitle: true,
    child: widget.loadAccess == null
        ? _offer(context)
        : ProAccessBuilder(
            load: widget.loadAccess!,
            builder: (context, access) => access.isPro
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Headline(
                        eyebrow: 'ENTRENAOP PRO',
                        title: 'Ya tienes Pro',
                        description: 'Tu acceso está activo. Puedes continuar con tu preparación.',
                      ),
                      const SizedBox(height: 24),
                      _AccessDetails(access, offerContext: widget.offerContext),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _close(context),
                        child: const Text('Volver'),
                      ),
                    ],
                  )
                : _offer(context),
          ),
  );

  Widget _offer(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Headline(
        eyebrow: 'ENTRENAOP PRO',
        title: 'Tu preparación, con un plan que se adapta a ti.',
        description: widget.offerContext.preparationName == null
            ? 'Un plan adaptativo según tu objetivo y lo que vas consiguiendo.'
            : 'Para tu preparación: ${widget.offerContext.preparationName}.',
      ),
      const SizedBox(height: 24),
      const _Benefit(
        Icons.flag_outlined,
        'Entrenamientos según tus marcas y objetivo.',
      ),
      const _Benefit(
        Icons.autorenew_rounded,
        'Las siguientes sesiones se ajustan con tus resultados.',
      ),
      const _Benefit(
        Icons.calendar_month_outlined,
        'Tu disponibilidad y material, tenidos en cuenta.',
      ),
      const _Benefit(
        Icons.add_circle_outline_rounded,
        'Más ejercicios y sesiones propios, sin las cuotas de Free.',
      ),
      const SizedBox(height: 12),
      Text(
        'El mismo Pro. Elige cómo pagar.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      RadioGroup<ProBillingPeriod>(
        groupValue: _period,
        onChanged: (value) {
          if (value != null) setState(() => _period = value);
        },
        child: Column(
          children: [
            for (final period in ProBillingPeriod.values) ...[
              _BillingChoice(period: period, selected: _period == period),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      const _UnavailableNotice(),
      const SizedBox(height: 16),
      // Hasta recibir productos reales y verificar derechos en servidor,
      // no existe una acción que cobre o conceda Pro desde esta pantalla.
      FilledButton(onPressed: null, child: Text(_period.subscribeLabel)),
      const SizedBox(height: 12),
      Text(
        '${_period.renewal} Puedes cancelar la renovación y conservar el acceso hasta finalizar el periodo contratado.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => _close(context),
        child: const Text('Seguir con Free'),
      ),
      const OutlinedButton(onPressed: null, child: Text('Restaurar compras')),
      const Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        children: [
          TextButton(onPressed: null, child: Text('Condiciones')),
          TextButton(onPressed: null, child: Text('Privacidad')),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'La restauración, las condiciones de contratación y la información de privacidad estarán disponibles antes de habilitar los pagos.',
      ),
    ],
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _BillingChoice extends StatelessWidget {
  const _BillingChoice({required this.period, required this.selected});
  final ProBillingPeriod period;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? colors.primaryContainer : colors.surfaceContainer,
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: RadioListTile<ProBillingPeriod>(
          value: period,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(period.label),
                  if (period == ProBillingPeriod.annual)
                    Text(
                      'Ahorra 37 %',
                      style: TextStyle(color: colors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${period.price} / ${period.unit}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              period == ProBillingPeriod.annual
                  ? 'Un cobro anual · equivale a 2,50 €/mes.\nAhorro respecto a 12 mensualidades.'
                  : 'Un cobro cada mes.',
            ),
          ),
        ),
      ),
    );
  }
}

class ProExamplePage extends StatelessWidget {
  const ProExamplePage({
    this.offerContext = const ProOfferContext(),
    super.key,
  });
  final ProOfferContext offerContext;

  static const _steps = [
    ('Tu punto de partida', 'Marcas, objetivo, días disponibles y material.'),
    (
      'Una propuesta de entrenamiento',
      'Para los programas adaptativos disponibles, revisas la propuesta antes de empezar.',
    ),
    (
      'Entrenas y registras resultados',
      'Lo que has realizado aporta contexto para continuar.',
    ),
    (
      'Las siguientes sesiones se ajustan',
      'El programa revisa la continuidad con tus resultados.',
    ),
  ];

  @override
  Widget build(BuildContext context) => _ProScaffold(
    title: 'Descubre Pro',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Headline(
          eyebrow: 'PRO · VISTA PREVIA',
          title: 'Así continúa tu preparación.',
          description: 'Ejemplo didáctico. No es una pauta personalizada.',
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                  child: Text('${i + 1}'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].$1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(_steps[i].$2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        FilledButton(
          onPressed: () => context.push(offerContext.location()),
          child: const Text('Ver modalidades de Pro'),
        ),
        TextButton(
          onPressed: () => _close(context),
          child: Text(
            offerContext.goalId == null
                ? 'Volver a Mi plan'
                : 'Volver a mi preparación',
          ),
        ),
      ],
    ),
  );
}

class ProSubscriptionPage extends StatelessWidget {
  const ProSubscriptionPage({this.loadAccess, super.key});
  final LoadProAccess? loadAccess;

  @override
  Widget build(BuildContext context) => _ProScaffold(
    title: 'Mi suscripción',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Headline(
          eyebrow: 'ENTRENAOP PRO',
          title: 'Tu acceso a Pro',
          description: 'Aquí podrás consultar y gestionar tu suscripción.',
        ),
        const SizedBox(height: 24),
        if (loadAccess != null)
          ProAccessBuilder(
            load: loadAccess!,
            showRefresh: true,
            builder: (_, access) => _AccessDetails(access),
          )
        else
          const _UnavailableNotice(),
        const SizedBox(height: 24),
        if (loadAccess == null)
          FilledButton(
            onPressed: () => context.push('/pro'),
            child: const Text('Conocer Pro'),
          ),
        const SizedBox(height: 16),
        const Text('Tus preparaciones, resultados e historial se conservan.'),
      ],
    ),
  );
}

class _AccessDetails extends StatelessWidget {
  const _AccessDetails(
    this.access, {
    this.offerContext = const ProOfferContext(),
  });
  final ProAccess access;
  final ProOfferContext offerContext;
  @override
  Widget build(BuildContext context) {
    final expiry = access.validUntil?.toLocal();
    final date = expiry == null
        ? ''
        : '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
    return EntrenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            access.isPro ? 'Pro activo' : 'Cuenta Free',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            access.isPro
                ? 'Acceso de prueba hasta el $date. No es una suscripción de pago.'
                : 'Incluye 8 ejercicios propios y 4 sesiones propias guardadas.',
          ),
          const SizedBox(height: 12),
          Text(
            'Ejercicios propios: ${access.personalExercises}${access.isPro ? '' : '/8'}',
          ),
          Text(
            'Sesiones propias: ${access.personalSessions}${access.isPro ? '' : '/4'}',
          ),
          const SizedBox(height: 12),
          const Text(
            'La contratación y restauración de compras todavía no están disponibles.',
          ),
          TextButton(
            onPressed: () => context.push(
              access.isPro && offerContext.goalId != null
                  ? '/plan/goal/${offerContext.goalId}/training'
                  : '/plan',
            ),
            child: Text(
              access.isPro && offerContext.goalId != null
                  ? 'Continuar con mi preparación'
                  : 'Ir a Mi plan',
            ),
          ),
          if (!access.isPro)
            FilledButton(
              onPressed: () => context.push(offerContext.location()),
              child: const Text('Conocer Pro'),
            ),
        ],
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) => EntrenaCard(
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contratación próximamente disponible.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(
          'Todavía no puedes comprar ni restaurar una suscripción. No se realizará ningún cobro.',
        ),
      ],
    ),
  );
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow, title, description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        eyebrow,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(description),
    ],
  );
}

void _close(BuildContext context) {
  // push/pop conserva la preparación, su scroll y los datos que la originaron.
  // Una URL directa no tiene ese origen: vuelve a Mi plan.
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/plan');
  }
}

class _ProScaffold extends StatelessWidget {
  const _ProScaffold({
    required this.title,
    required this.child,
    this.brandTitle = false,
  });
  final String title;
  final Widget child;
  final bool brandTitle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: brandTitle ? const ProBrandTitle() : Text(title),
      leading: IconButton(
        tooltip: 'Cerrar',
        onPressed: () => _close(context),
        icon: const Icon(Icons.close_rounded),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
    ),
  );
}
