import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/pro_access.dart';
import '../../domain/pro_offer.dart';
import '../../domain/pro_purchases.dart';

enum ProPurchasePhase {
  unavailable,
  loading,
  ready,
  working,
  pending,
  error,
  active,
}

class ProPurchaseState {
  const ProPurchaseState(
    this.phase, {
    this.products = const [],
    this.message,
    this.access,
  });
  final ProPurchasePhase phase;
  final List<ProStoreProduct> products;
  final String? message;
  final ProAccess? access;
}

class ProPurchaseCubit extends Cubit<ProPurchaseState> {
  ProPurchaseCubit(this.repository)
    : super(const ProPurchaseState(ProPurchasePhase.loading));
  final ProPurchaseRepository repository;
  bool _busy = false;
  Future<void> load() async {
    if (_busy || isClosed) return;
    if (!repository.enabled) {
      emit(
        ProPurchaseState(
          ProPurchasePhase.unavailable,
          message: repository.unavailableMessage,
        ),
      );
      return;
    }
    _busy = true;
    emit(const ProPurchaseState(ProPurchasePhase.loading));
    try {
      final products = await repository.products();
      if (!isClosed) {
        emit(ProPurchaseState(ProPurchasePhase.ready, products: products));
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const ProPurchaseState(
            ProPurchasePhase.error,
            message:
                'No se han podido cargar las modalidades. Vuelve a intentarlo.',
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> buy(ProBillingPeriod period) async {
    if (state.phase != ProPurchasePhase.ready ||
        !state.products.any((product) => product.period == period)) {
      return;
    }
    await _operate(() => repository.purchase(period), freeIsPending: true);
  }

  Future<void> restore() => _operate(repository.restore);
  Future<void> synchronize() => _operate(repository.synchronize);
  Future<void> _operate(
    Future<ProAccess> Function() action, {
    bool freeIsPending = false,
  }) async {
    if (_busy || isClosed || !repository.enabled) return;
    final products = state.products;
    final wasPending = state.phase == ProPurchasePhase.pending;
    _busy = true;
    emit(ProPurchaseState(ProPurchasePhase.working, products: products));
    try {
      final access = await action();
      if (isClosed) return;
      emit(
        ProPurchaseState(
          access.isPro
              ? ProPurchasePhase.active
              : freeIsPending || wasPending
              ? ProPurchasePhase.pending
              : ProPurchasePhase.ready,
          products: products,
          access: access,
          message: access.isPro
              ? null
              : freeIsPending || wasPending
              ? 'Todavía no hay acceso Pro confirmado. Comprueba de nuevo en unos segundos.'
              : 'No se han encontrado compras con acceso Pro vigente para esta cuenta.',
        ),
      );
    } on ProPurchaseException catch (error) {
      if (!isClosed) {
        emit(
          ProPurchaseState(
            error.pending || wasPending
                ? ProPurchasePhase.pending
                : ProPurchasePhase.ready,
            products: products,
            message: error.cancelled ? null : error.message,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          ProPurchaseState(
            wasPending ? ProPurchasePhase.pending : ProPurchasePhase.ready,
            products: products,
            message:
                'No se ha podido completar la operación. Vuelve a intentarlo.',
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }
}
