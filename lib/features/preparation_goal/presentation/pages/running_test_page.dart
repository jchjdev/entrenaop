import 'package:entrenaop/features/preparation_goal/data/repositories/running_test_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/duration_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RunningTestPage extends StatefulWidget {
  const RunningTestPage({
    super.key,
    required this.goalId,
    required this.repository,
  });

  final String goalId;
  final RunningTestRepository repository;

  @override
  State<RunningTestPage> createState() => _RunningTestPageState();
}

class _RunningTestPageState extends State<RunningTestPage> {
  late Future<List<RunningTestResult>> _history = widget.repository.history(
    widget.goalId,
  );

  void _reload() => setState(() {
    _history = widget.repository.history(widget.goalId);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Test de 2 km')),
    body: FutureBuilder<List<RunningTestResult>>(
      future: _history,
      builder: (context, snapshot) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Control de carrera',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta marca pertenece solo a esta preparación. Puedes repetir el test y conservar el historial.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Antes de hacerlo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Calienta, realiza movilidad dinámica y progresa gradualmente antes del esfuerzo. El protocolo deportivo definitivo está pendiente de revisión con el entrenador.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final saved = await context.push<bool>(
                  '/plan/goal/${widget.goalId}/running-test/new',
                );
                if (saved == true && mounted) _reload();
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar marca de 2 km'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Historial',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              TextButton(
                onPressed: _reload,
                child: const Text('No se pudo cargar. Reintentar'),
              )
            else if (snapshot.data!.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Aún no hay marcas registradas.'),
              )
            else
              ...snapshot.data!.map(
                (result) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(result.completedAt)} · ${_formatTime(result.durationSeconds)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'RPE ${result.rpe}/10${result.averageHrBpm == null ? '' : ' · FC media ${result.averageHrBpm}'}${result.maxHrBpm == null ? '' : ' · FC máx. ${result.maxHrBpm}'}',
                        ),
                        if (result.splitsSeconds != null)
                          Text(
                            '400 m: ${result.splitsSeconds!.map(_formatTime).join(' · ')}',
                          ),
                        if (result.notes != null && result.notes!.isNotEmpty)
                          Text(result.notes!),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class RunningTestFormPage extends StatefulWidget {
  const RunningTestFormPage({
    super.key,
    required this.goalId,
    required this.repository,
  });
  final String goalId;
  final RunningTestRepository repository;

  @override
  State<RunningTestFormPage> createState() => _RunningTestFormState();
}

class _RunningTestFormState extends State<RunningTestFormPage> {
  final _time = TextEditingController();
  final _averageHr = TextEditingController();
  final _maxHr = TextEditingController();
  final _notes = TextEditingController();
  final _splits = List.generate(5, (_) => TextEditingController());
  int? _rpe;
  DateTime _completedAt = DateTime.now();
  bool _showSplits = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _time.dispose();
    _averageHr.dispose();
    _maxHr.dispose();
    _notes.dispose();
    for (final split in _splits) {
      split.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final splitValues = _showSplits
        ? _splits.map((value) => parseDurationInput(value.text)).toList()
        : null;
    if (_showSplits && splitValues!.any((value) => value == null)) {
      setState(
        () => _error = 'Introduce los cinco parciales o desactiva el detalle.',
      );
      return;
    }
    final result = RunningTestResult(
      completedAt: _completedAt,
      durationSeconds: parseDurationInput(_time.text) ?? 0,
      rpe: _rpe ?? 0,
      averageHrBpm: int.tryParse(_averageHr.text),
      maxHrBpm: int.tryParse(_maxHr.text),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      splitsSeconds: splitValues?.cast<int>(),
    );
    final error = result.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(widget.goalId, result);
      if (mounted) {
        context.pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No se ha podido guardar la marca. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nueva marca de 2 km')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _completedAt,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(
                () => _completedAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  12,
                ),
              );
            }
          },
          icon: const Icon(Icons.calendar_today),
          label: Text(
            'Fecha: ${DateFormat('dd/MM/yyyy').format(_completedAt)}',
          ),
        ),
        const SizedBox(height: 12),
        _durationField(_time, 'Tiempo total de 2 km', 'Ejemplo: 8:30'),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _rpe,
          decoration: const InputDecoration(
            labelText: 'Esfuerzo percibido (RPE) *',
          ),
          items: [
            for (var value = 1; value <= 10; value++)
              DropdownMenuItem(value: value, child: Text('$value/10')),
          ],
          onChanged: (value) => setState(() => _rpe = value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _hrField(_averageHr, 'FC media (opcional)')),
            const SizedBox(width: 12),
            Expanded(child: _hrField(_maxHr, 'FC máxima (opcional)')),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Incidencias o notas (opcional)',
          ),
        ),
        SwitchListTile(
          title: const Text('Añadir parciales de 400 m'),
          subtitle: const Text('Recomendados, pero no obligatorios.'),
          value: _showSplits,
          onChanged: (value) => setState(() => _showSplits = value),
        ),
        if (_showSplits)
          for (var index = 0; index < 5; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _durationField(
                _splits[index],
                'Parcial ${index + 1} · 400 m',
                'Ejemplo: 1:42',
              ),
            ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar marca'),
        ),
      ],
    ),
  );
}

Widget _durationField(
  TextEditingController controller,
  String label,
  String hint,
) => TextField(
  controller: controller,
  keyboardType: TextInputType.number,
  inputFormatters: const [DurationInputFormatter()],
  decoration: InputDecoration(labelText: label, hintText: hint),
);

Widget _hrField(TextEditingController controller, String label) => TextField(
  controller: controller,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(3),
  ],
  decoration: InputDecoration(labelText: label),
);

String _formatTime(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
