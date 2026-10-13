import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/pro_offer.dart';
import '../../domain/pro_purchases.dart';
import '../bloc/pro_purchase_cubit.dart';

class ProPurchasePanel extends StatefulWidget {
  const ProPurchasePanel({
    required this.repository,
    required this.onVerified,
    this.showPlans = true,
    super.key,
  });
  final ProPurchaseRepository repository;
  final VoidCallback onVerified;
  final bool showPlans;
  @override
  State<ProPurchasePanel> createState() => _ProPurchasePanelState();
}

class _ProPurchasePanelState extends State<ProPurchasePanel> {
  late final ProPurchaseCubit _cubit = ProPurchaseCubit(widget.repository)
    ..load();
  ProBillingPeriod _period = ProBillingPeriod.annual;
  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ProPurchaseCubit, ProPurchaseState>(
    bloc: _cubit,
    listenWhen: (_, next) => next.phase == ProPurchasePhase.active,
    listener: (_, _) => widget.onVerified(),
    child: BlocBuilder<ProPurchaseCubit, ProPurchaseState>(
      bloc: _cubit,
      builder: (context, state) {
        final busy =
            state.phase == ProPurchasePhase.working ||
            state.phase == ProPurchasePhase.loading;
        final pending = state.phase == ProPurchasePhase.pending;
        final selected = state.products
            .where((product) => product.period == _period)
            .firstOrNull;
        final monthly = state.products
            .where((product) => product.period == ProBillingPeriod.monthly)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Compras de prueba. No se realizará ningún cobro.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (state.message != null) ...[
              Text(state.message!, semanticsLabel: state.message!),
              const SizedBox(height: 12),
            ],
            if (widget.showPlans && state.products.isNotEmpty) ...[
              RadioGroup<ProBillingPeriod>(
                groupValue: _period,
                onChanged: busy || pending
                    ? (_) {}
                    : (period) {
                        if (period != null) setState(() => _period = period);
                      },
                child: Column(
                  children: [
                    for (final product in state.products) ...[
                      _StoreChoice(
                        product: product,
                        monthly: monthly,
                        selected: product.period == _period,
                        enabled: !busy && !pending,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              FilledButton(
                onPressed: busy || pending || selected == null
                    ? null
                    : () => _cubit.buy(_period),
                child: Text(
                  selected == null
                      ? 'Probar suscripción'
                      : 'Probar por ${selected.priceLabel}/${selected.period.unit}',
                ),
              ),
            ],
            if (state.phase == ProPurchasePhase.error)
              TextButton(
                onPressed: _cubit.load,
                child: const Text('Reintentar'),
              ),
            if (pending)
              FilledButton(
                onPressed: busy ? null : _cubit.synchronize,
                child: const Text('Comprobar acceso'),
              ),
            OutlinedButton(
              onPressed: busy || pending || !widget.repository.enabled
                  ? null
                  : _cubit.restore,
              child: const Text('Restaurar compras'),
            ),
          ],
        );
      },
    ),
  );
}

class _StoreChoice extends StatelessWidget {
  const _StoreChoice({
    required this.product,
    required this.monthly,
    required this.selected,
    required this.enabled,
  });
  final ProStoreProduct product;
  final ProStoreProduct? monthly;
  final bool selected, enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final annual = product.period == ProBillingPeriod.annual;
    // Solo se comparan precios de la misma moneda, recibidos del catálogo.
    final saving =
        annual &&
            monthly != null &&
            monthly!.price > 0 &&
            monthly!.currencyCode == product.currencyCode
        ? ((1 - product.price / (monthly!.price * 12)) * 100).floor()
        : 0;
    final equivalent = NumberFormat.simpleCurrency(
      locale: 'es',
      name: product.currencyCode,
    ).format(product.price / 12);
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
          value: product.period,
          enabled: enabled,
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
                children: [
                  Text(product.period.label),
                  if (saving > 0)
                    Text(
                      'Ahorra $saving %',
                      style: TextStyle(color: colors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${product.priceLabel} / ${product.period.unit}',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              annual
                  ? 'Un cobro anual · equivale a $equivalent/mes.${saving > 0 ? '\nAhorro respecto a 12 mensualidades.' : ''}'
                  : 'Un cobro cada mes.',
            ),
          ),
        ),
      ),
    );
  }
}
