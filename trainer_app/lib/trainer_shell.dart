import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/professional_tools_workspace.dart';

/// Los formularios mantienen toda la pantalla y su guard de salida propio.
class TrainerShell extends StatefulWidget {
  const TrainerShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const destinations = [
    ('/home', 'Inicio', Icons.home_outlined),
    ('/clients', 'Alumnos', Icons.people_outline),
    ('/agenda', 'Agenda', Icons.calendar_month_outlined),
    ('/workouts', 'Sesiones', Icons.fitness_center),
    ('/programs', 'Programas', Icons.view_week_outlined),
    ('/exercises', 'Ejercicios', Icons.sports_gymnastics),
    ('/reviews', 'Revisiones', Icons.fact_check_outlined),
    ('/forms', 'Formularios', Icons.assignment_outlined),
    ('/assessments', 'Pruebas y simulacros', Icons.timer_outlined),
    ('/groups', 'Grupos', Icons.groups_outlined),
    ('/media', 'Vídeos', Icons.video_library_outlined),
    ('/recurrence', 'Programar semanas', Icons.event_repeat_outlined),
    ('/messages', 'Conversaciones', Icons.chat_bubble_outline),
    ('/reports', 'Informes', Icons.insights),
    ('/settings', 'Mi cuenta', Icons.settings_outlined),
  ];
  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  String get location => widget.location;
  Widget get child => widget.child;
  static const destinations = TrainerShell.destinations;

  @override
  Widget build(BuildContext context) =>
      ProfessionalToolsWorkspace(child: Builder(builder: _buildShell));

  Widget _buildShell(BuildContext context) {
    final index = destinations.indexWhere((d) => location.startsWith(d.$1));
    final selected = index >= 0
        ? index
        : destinations.indexWhere(
            (d) =>
                d.$1 ==
                (location.startsWith('/conversations/')
                    ? '/messages'
                    : '/agenda'),
          );
    void go(int value) {
      if (location != destinations[value].$1) {
        context.go(destinations[value].$1);
      }
    }

    Future<void> more() async {
      final destination = await showModalBottomSheet<int>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Calculadora de ritmos'),
                subtitle: const Text('Herramientas'),
                onTap: () => Navigator.pop(sheetContext, -1),
              ),
              for (var i = 4; i < destinations.length; i++)
                ListTile(
                  leading: Icon(destinations[i].$3),
                  title: Text(destinations[i].$2),
                  selected: selected == i,
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      );
      if (destination != null && context.mounted) {
        if (destination == -1) {
          ProfessionalToolsWorkspace.openCalculator(context);
        } else {
          go(destination);
        }
      }
    }

    return ProfessionalWorkspaceShell(
      scaffoldKey: _scaffold,
      navigation: Material(
        color: context.visuals.surfaceLow,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntrenaWordmark(width: 132),
                    SizedBox(height: 8),
                    Text(
                      'PREPARADORES',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (const {
                        0: 'TU ESPACIO',
                        3: 'BIBLIOTECA',
                        6: 'SEGUIMIENTO',
                        9: 'ORGANIZACIÓN',
                        12: 'SERVICIO',
                      }.containsKey(i))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 14, 10, 7),
                          child: Text(
                            const {
                              0: 'TU ESPACIO',
                              3: 'BIBLIOTECA',
                              6: 'SEGUIMIENTO',
                              9: 'ORGANIZACIÓN',
                              12: 'SERVICIO',
                            }[i]!,
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: .9,
                              color: Color(0xFFAAB5C4),
                            ),
                          ),
                        ),
                      ListTile(
                        dense: true,
                        minTileHeight: 36,
                        minVerticalPadding: 4,
                        key: ValueKey('trainer-nav-${destinations[i].$1}'),
                        selected: selected == i,
                        selectedTileColor: context.visuals.accentSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        minLeadingWidth: 22,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        leading: Icon(destinations[i].$3, size: 18),
                        title: Text(destinations[i].$2),
                        onTap: () => go(i),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: ProfessionalToolsButton(),
              ),
            ],
          ),
        ),
      ),
      headerBuilder: (context, desktop) => desktop
          ? AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                'Preparadores / ${destinations[selected].$2}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              actions: const [
                ProfessionalToolsButton(iconOnly: true),
                SizedBox(width: 12),
              ],
            )
          : const SizedBox.shrink(),
      compactNavigation: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: TextButton(
                    onPressed: i == 4 ? more : () => go(i),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      backgroundColor:
                          (i == selected || (i == 4 && selected >= 4))
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(i == 4 ? Icons.more_horiz : destinations[i].$3),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            i == 4 ? 'Más' : destinations[i].$2,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: child,
    );
  }
}
