import 'package:entrena_ui/conversation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/contact/domain.dart';
import 'package:trainer_access/contact/presentation.dart';
import 'package:trainer_access/directory/domain.dart';
import 'package:trainer_access/trainer_message.dart';

class _Contacts implements ContactRepository {
  ContactState state = ContactState.fresh;
  bool isTrainer = false, loseResponse = false;
  String? relationId;
  final operations = <String>[];
  final messagesById = <String, TrainerMessage>{};
  final reads = <String>{};
  int decisions = 0;
  ContactConversation get snapshot => ContactConversation(
    id: state == ContactState.fresh ? null : 'contact',
    profileId: 'profile',
    relationId: relationId,
    name: isTrainer ? 'Isabel' : 'Preparador',
    state: state,
    isTrainer: isTrainer,
    canSend: state == ContactState.fresh || state == ContactState.accepted,
  );
  void message(String id, String body, {bool mine = true}) {
    messagesById[id] = TrainerMessage.fromJson({
      'id': id,
      'body': body,
      'sender_id': mine ? 'actor' : 'other',
      'created_at': '2026-10-31T12:00:00Z',
    }, 'actor');
  }

  @override
  Future<ContactConversation> open(String profileId) async => snapshot;
  @override
  Future<ContactConversation> context(String id) async => snapshot;
  @override
  Future<ContactConversation> request({
    required String operationId,
    required String profileId,
    required String body,
  }) async {
    operations.add(operationId);
    state = ContactState.pending;
    message(operationId, body);
    if (loseResponse) {
      loseResponse = false;
      throw const DirectoryFailure('Respuesta perdida de prueba');
    }
    return snapshot;
  }

  @override
  Future<void> decide(String id, ContactState next) async {
    state = next;
    decisions++;
  }

  @override
  Future<List<TrainerMessage>> messages(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  }) async => messagesById.values.toList();
  @override
  Future<void> send({
    required String operationId,
    required String contactId,
    required String body,
  }) async {
    operations.add(operationId);
    message(operationId, body);
  }

  @override
  Future<void> markRead(String contactId, List<String> ids) async {
    reads.addAll(ids);
  }

  @override
  Future<ContactInbox> inbox({ContactConversation? before}) async =>
      ContactInbox([snapshot]);
  @override
  Future<void> report(
    String id,
    DirectoryReportReason reason,
    String details,
  ) async {}
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Contacts repository, {
    List<String>? service,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ContactConversationPage(
          repository: repository,
          profileId: repository.state == ContactState.fresh ? 'profile' : null,
          contactId: repository.state == ContactState.fresh ? null : 'contact',
          onService: (id) => service?.add(id),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  }

  testWidgets('contacto legible a 320 px y texto doble', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Contacts();
    await mount(tester, repository, textScale: 2);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Privacidad del contacto'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Privacidad del contacto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('información adicional 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al pasar a alumno conserva el borrador visible para copiarlo', (
    tester,
  ) async {
    final repository = _Contacts()..state = ContactState.accepted;
    final service = <String>[];
    await mount(tester, repository, service: service);
    await tester.enterText(
      find.byType(TextField),
      'Borrador que quiero conservar',
    );
    await tester.pump();
    repository.relationId = 'service';
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Borrador que quiero conservar');
    expect(field.readOnly, isTrue);
    expect(find.text('Puedes copiar tu borrador.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Enviar mensaje'),
          )
          .onPressed,
      isNull,
    );
    expect(service, ['service']);
    expect(repository.operations, isEmpty);
  });

  testWidgets('primer contacto reutiliza conversación y espera aceptación', (
    tester,
  ) async {
    final repository = _Contacts();
    await mount(tester, repository);
    expect(find.byType(ConversationView), findsOneWidget);
    expect(
      find.textContaining('El preparador recibirá tu nombre'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'Hola, quiero consultar disponibilidad',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Enviar mensaje'));
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(repository.messagesById.length, 1);
    expect(
      find.textContaining('Tu primer mensaje está enviado'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(repository.decisions, 0);
  });

  testWidgets(
    'respuesta perdida conserva UUID y primer mensaje al reintentar',
    (tester) async {
      final repository = _Contacts()..loseResponse = true;
      await mount(tester, repository);
      await tester.enterText(find.byType(TextField), 'Consulta de precio');
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta perdida de prueba'), findsOneWidget);
      await tester.ensureVisible(find.text('Reintentar el mismo envío'));
      await tester.tap(find.text('Reintentar el mismo envío'));
      await tester.pumpAndSettle();
      expect(repository.operations.length, 2);
      expect(repository.operations.toSet().length, 1);
      expect(repository.messagesById.length, 1);
    },
  );

  testWidgets(
    'preparador acepta y responde con los mismos mensajes y lecturas',
    (tester) async {
      final repository = _Contacts()
        ..state = ContactState.pending
        ..isTrainer = true;
      repository.message(
        'initial',
        'Hola, me gustaría información',
        mine: false,
      );
      await mount(tester, repository);
      expect(repository.reads, contains('initial'));
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Aceptar contacto'));
      await tester.pumpAndSettle();
      expect(repository.state, ContactState.accepted);
      expect(find.text('Hola, me gustaría información'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Cuéntame qué necesitas');
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(repository.messagesById.length, 2);
    },
  );

  testWidgets('vínculo existente abre el chat de preparación', (tester) async {
    final repository = _Contacts()..relationId = 'relation';
    final opened = <String>[];
    await mount(tester, repository, service: opened);
    expect(opened, ['relation']);
    expect(find.text('Abrir chat de preparación'), findsOneWidget);
    expect(repository.operations, isEmpty);
  });

  testWidgets('bloqueo requiere confirmación y conserva lectura', (
    tester,
  ) async {
    final repository = _Contacts()..state = ContactState.accepted;
    repository.message('initial', 'Consulta inicial');
    await mount(tester, repository);
    await tester.tap(find.text('Bloquear contacto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.decisions, 0);
    await tester.tap(find.text('Bloquear contacto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pumpAndSettle();
    expect(repository.state, ContactState.blocked);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Consulta inicial'), findsOneWidget);
  });
}
