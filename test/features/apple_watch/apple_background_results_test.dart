import 'dart:async';

import 'package:entrenaop/features/apple_watch/domain/apple_results_wakeup.dart';
import 'package:entrenaop/features/apple_watch/presentation/apple_results_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apple_results_test.dart' as fixture;

class Wakeup implements AppleResultsWakeup {
  String? owner;
  Future<bool> Function()? changed;
  @override
  Future<bool> configure(
    String? owner,
    Future<bool> Function() synchronize,
  ) async {
    this.owner = owner;
    changed = synchronize;
    return owner != null;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'Reautorizar la recogida conserva un aviso válido de la configuración nueva',
    (tester) async {
      final repository = fixture.Repository();
      final reader = fixture.Reader();
      final wakeup = Wakeup();
      final coordinator = AppleResultsCoordinator(
        (_) => repository,
        reader,
        wakeup: wakeup,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      final oldNotice = wakeup.changed!;
      await coordinator.enable(true);
      expect(await oldNotice(), isFalse);
      expect(await wakeup.changed!(), isTrue);
      coordinator.dispose();
    },
  );
  testWidgets('Un aviso de Salud recoge datos sin volver a primer plano', (
    tester,
  ) async {
    final repository = fixture.Repository();
    final reader = fixture.Reader();
    final wakeup = Wakeup();
    final coordinator = AppleResultsCoordinator(
      (_) => repository,
      reader,
      wakeup: wakeup,
    );
    coordinator.setAccount('owner');
    await tester.pump();
    expect(coordinator.backgroundEnabled, isTrue);
    coordinator.foreground(false);
    final before = repository.saves;
    expect(await wakeup.changed!(), isTrue);
    expect(repository.saves, before + 1);
    coordinator.dispose();
  });

  testWidgets(
    'Un aviso durante una lectura espera y recoge la actualización posterior',
    (tester) async {
      final repository = fixture.Repository();
      final reader = fixture.Reader();
      final wakeup = Wakeup();
      final coordinator = AppleResultsCoordinator(
        (_) => repository,
        reader,
        wakeup: wakeup,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      final pending = Completer<void>();
      reader.action = () async {
        await pending.future;
        return [fixture.observation];
      };
      final first = coordinator.refresh();
      await tester.pump();
      final count = reader.reads;
      final notification = wakeup.changed!();
      pending.complete();
      await first;
      expect(await notification, isTrue);
      expect(reader.reads, count + 1);
      coordinator.dispose();
    },
  );

  testWidgets(
    'Una respuesta tardía tras salir no acusa una importación ni conserva la cuenta',
    (tester) async {
      final repository = fixture.Repository();
      final reader = fixture.Reader();
      final wakeup = Wakeup();
      final coordinator = AppleResultsCoordinator(
        (_) => repository,
        reader,
        wakeup: wakeup,
      );
      coordinator.setAccount('owner');
      await tester.pump();
      final pending = Completer<void>();
      reader.action = () async {
        await pending.future;
        return [fixture.observation];
      };
      final before = repository.saves;
      final notification = wakeup.changed!();
      await tester.pump();
      coordinator.setAccount(null);
      pending.complete();
      expect(await notification, isFalse);
      expect(repository.saves, before);
      expect(wakeup.owner, isNull);
      expect(coordinator.catalog, isNull);
      coordinator.dispose();
    },
  );
}
