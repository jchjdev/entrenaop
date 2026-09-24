import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FasPeriodicHistoryPage extends StatefulWidget {
  const FasPeriodicHistoryPage({
    super.key,
    required this.repository,
    this.reference,
  });

  final FasPeriodicAssessmentRepository repository;
  final FasPeriodic2027Reference? reference;

  @override
  State<FasPeriodicHistoryPage> createState() => _FasPeriodicHistoryPageState();
}

class _FasPeriodicHistoryPageState extends State<FasPeriodicHistoryPage> {
  late Future<_HistoryData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_HistoryData> _load() async => _HistoryData(
    entries: await widget.repository.history(),
    reference: widget.reference ?? await FasPeriodic2027Reference.load(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historial de tests FAS')),
    body: FutureBuilder<_HistoryData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(() => _data = _load()),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          );
        }
        final data = snapshot.data!;
        if (data.entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no has guardado ningún test. Tus simulaciones no aparecen aquí.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            final refreshed = _load();
            setState(() => _data = refreshed);
            await refreshed;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _HistoryCard(
              entry: data.entries[index],
              reference: data.reference,
            ),
          ),
        );
      },
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.reference});

  final FasPeriodicAssessmentEntry entry;
  final FasPeriodic2027Reference reference;

  @override
  Widget build(BuildContext context) {
    if (entry.scoringVersion != FasPeriodic2027Reference.version) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.update_outlined),
          title: Text(DateFormat('dd/MM/yyyy').format(entry.completedAt)),
          subtitle: const Text(
            'Este test usa otra versión del baremo. Actualiza la app para consultar sus puntos.',
          ),
        ),
      );
    }
    final category = AssessmentCategory.values.byName(entry.category);
    final scores = <String, PeriodicScoreResult>{
      for (final mark in entry.marks)
        mark.testId: reference.scoreFor(
          testId: mark.testId,
          category: category,
          age: entry.age,
          mark: mark.value,
        )!,
    };
    final total = scores.values.fold<int>(
      0,
      (sum, result) => sum + result.points,
    );
    return Card(
      child: ExpansionTile(
        title: Text(
          '$total puntos',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy').format(entry.completedAt)} · ${entry.age} años · ${entry.category == 'men' ? 'H' : 'M'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final mark in entry.marks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(mark.testName),
              subtitle: Text(_formatStoredMark(mark)),
              trailing: Text(
                '${scores[mark.testId]!.points} puntos',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatStoredMark(FasPeriodicAssessmentMark mark) => switch (mark.unit) {
  'repetitions' => '${mark.value} repeticiones',
  'milliseconds' when mark.testId == 'agility_speed_circuit' =>
    '${(mark.value / 1000).toStringAsFixed(2).replaceAll('.', ',')} s',
  'milliseconds' =>
    '${mark.value ~/ 60000}:${((mark.value ~/ 1000) % 60).toString().padLeft(2, '0')}',
  _ => '${mark.value}',
};

class _HistoryData {
  const _HistoryData({required this.entries, required this.reference});

  final List<FasPeriodicAssessmentEntry> entries;
  final FasPeriodic2027Reference reference;
}
