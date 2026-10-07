import 'dart:async';

import 'package:entrenaop/core/config/app_config.dart';
import 'package:entrenaop/features/plan_preview/data/shared_preferences_plan_preview_store.dart';
import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('el selector solo está permitido fuera de release y en desarrollo', () {
    for (final environment in AppEnvironment.values) {
      for (final release in [true, false]) {
        expect(
          AppConfig.allowsPlanPreview(
            environment: environment,
            release: release,
          ),
          environment == AppEnvironment.development && !release,
        );
      }
    }
  });

  test(
    'empieza en Pro y conserva la vista por cuenta sin heredar otra',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesPlanPreviewStore(
        await SharedPreferences.getInstance(),
      );
      final cubit = PlanPreviewCubit(enabled: true, store: store)
        ..bindAccount('a');
      addTearDown(cubit.close);
      expect(cubit.state.tier, PlanPreviewTier.pro);
      await cubit.select(PlanPreviewTier.free);
      expect(cubit.state.isFree, isTrue);
      cubit.bindAccount('b');
      expect(cubit.state.tier, PlanPreviewTier.pro);
      cubit.bindAccount(null);
      expect(cubit.state.available, isFalse);
      cubit.bindAccount('a');
      expect(cubit.state.tier, PlanPreviewTier.free);
      final restored = PlanPreviewCubit(enabled: true, store: store)
        ..bindAccount('a');
      addTearDown(restored.close);
      expect(restored.state.isFree, isTrue);
    },
  );

  test('deshabilitado no consulta ni guarda preferencias de nivel', () async {
    final store = _Store();
    final cubit = PlanPreviewCubit(enabled: false, store: store)
      ..bindAccount('a');
    addTearDown(cubit.close);
    await cubit.select(PlanPreviewTier.free);
    expect(store.reads, 0);
    expect(store.writes, 0);
    expect(cubit.state.available, isFalse);
    expect(cubit.state.isFree, isFalse);
  });

  test(
    'un guardado tardío no sustituye la vista de una cuenta nueva',
    () async {
      final store = _Store()..pending = Completer<void>();
      final cubit = PlanPreviewCubit(enabled: true, store: store)
        ..bindAccount('a');
      addTearDown(cubit.close);
      final pending = cubit.select(PlanPreviewTier.free);
      cubit.bindAccount('b');
      store.pending!.complete();
      await pending;
      expect(cubit.state.userId, 'b');
      expect(cubit.state.tier, PlanPreviewTier.pro);
    },
  );

  test(
    'un fallo de guardado conserva la vista anterior y permite reintentar',
    () async {
      final store = _Store()..fail = true;
      final cubit = PlanPreviewCubit(enabled: true, store: store)
        ..bindAccount('a');
      addTearDown(cubit.close);
      await cubit.select(PlanPreviewTier.free);
      expect(cubit.state.tier, PlanPreviewTier.pro);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.saving, isFalse);
      store.fail = false;
      await cubit.select(PlanPreviewTier.free);
      expect(cubit.state.isFree, isTrue);
      expect(cubit.state.error, isNull);
    },
  );
}

class _Store implements PlanPreviewStore {
  int reads = 0;
  int writes = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  PlanPreviewTier read(String userId) {
    reads++;
    return PlanPreviewTier.pro;
  }

  @override
  Future<void> save(String userId, PlanPreviewTier tier) async {
    writes++;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('fallo de prueba');
  }
}
