import 'package:entrenaop/features/preparation_goal/data/initial_week_draft_catalog.dart';
import 'package:flutter/material.dart';

/// Vista de contenido deportivo en revisión; no prescribe ni agenda sesiones.
class RunningWeekPrototypeCard extends StatefulWidget {
  const RunningWeekPrototypeCard({super.key});

  @override
  State<RunningWeekPrototypeCard> createState() =>
      _RunningWeekPrototypeCardState();
}

class _RunningWeekPrototypeCardState extends State<RunningWeekPrototypeCard> {
  late final Future<InitialWeekDraft> _draft = InitialWeekDraftCatalog.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InitialWeekDraft>(
      future: _draft,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No se ha podido cargar la semana de ejemplo.'),
            ),
          );
        }
        final draft = snapshot.data;
        if (draft == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return Card(
          color: const Color(0xFF1D1917),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.science_outlined, color: Color(0xFFFFA477)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Laboratorio · semana de ejemplo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Borrador deportivo · ${draft.version}',
                  style: const TextStyle(
                    color: Color(0xFFFFA477),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  draft.intro,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 12),
                for (final session in draft.sessions)
                  _PrototypeSession(session: session),
                const SizedBox(height: 8),
                Text(
                  draft.cycleNote,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrototypeSession extends StatelessWidget {
  const _PrototypeSession({required this.session});

  final InitialWeekDraftSession session;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF493024),
        foregroundColor: const Color(0xFFFFB18A),
        child: Text(session.dayLabel.split(' ').last),
      ),
      title: Text(
        session.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${session.dayLabel} · ${session.subtitle}'),
      children: [
        for (final detail in session.details)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('• $detail', style: const TextStyle(height: 1.35)),
            ),
          ),
      ],
    );
  }
}
