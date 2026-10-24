import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/professional_tools_workspace.dart';

import 'app_config.dart';

/// Solo organiza la interfaz. Cada ruta y cada operación mantienen sus permisos.
class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.path,
    required this.hasAccess,
    required this.onSignOut,
    required this.child,
    this.canManageAccounts,
    this.hasGuidedPrograms = false,
    this.hasOperations = false,
    super.key,
  });

  final String path;
  final Future<bool> Function() hasAccess;
  final Future<bool> Function()? canManageAccounts;
  final VoidCallback onSignOut;
  final bool hasGuidedPrograms;
  final bool hasOperations;
  final Widget child;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  late Future<({bool admin, bool accounts, bool accountsFailed})> _access =
      _loadAccess();

  Future<({bool admin, bool accounts, bool accountsFailed})>
  _loadAccess() async {
    if (!await widget.hasAccess()) {
      return (admin: false, accounts: false, accountsFailed: false);
    }
    try {
      return (
        admin: true,
        accounts: await widget.canManageAccounts?.call() ?? false,
        accountsFailed: false,
      );
    } catch (_) {
      // Un fallo comercial no bloquea la autoría ni muestra acceso a cuentas.
      return (admin: true, accounts: false, accountsFailed: true);
    }
  }

  void _retryAccess() {
    setState(() {
      _access = _loadAccess();
    });
  }

  void _navigate(String path) {
    _scaffold.currentState?.closeDrawer();
    if (path != widget.path) context.go(path);
  }

  @override
  Widget build(BuildContext context) =>
      ProfessionalToolsWorkspace(child: _buildShell(context));

  Widget _buildShell(BuildContext context) {
    final section = _sections.firstWhere(
      (section) => section.contains(widget.path),
      orElse: () => _sections.first,
    );
    final wide =
        MediaQuery.sizeOf(context).width >= 1100 &&
        MediaQuery.textScalerOf(context).scale(16) <= 24;
    final isSectionRoot =
        section.path == widget.path || widget.path == '/laboratory/push-ups';
    return AdminShellScope(
      isSectionRoot: isSectionRoot,
      child: Scaffold(
        key: _scaffold,
        drawer: wide
            ? null
            : Drawer(
                width: MediaQuery.sizeOf(context).width
                    .clamp(0, 320)
                    .toDouble(),
                child: _sidebar(),
              ),
        body: Row(
          children: [
            if (wide) SizedBox(width: 248, child: _sidebar()),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    automaticallyImplyLeading: false,
                    leading: wide
                        ? null
                        : IconButton(
                            tooltip: 'Abrir navegación',
                            onPressed: () =>
                                _scaffold.currentState!.openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                          ),
                    title: wide
                        ? Text(
                            '${section.group} / ${section.label}',
                            style: Theme.of(context).textTheme.titleSmall,
                          )
                        : const EntrenaWordmark(width: 132),
                    actions: [
                      const ProfessionalToolsButton(iconOnly: true),
                      if (wide)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _EnvironmentLabel(),
                        ),
                      // Volver al catálogo activa primero el guard del editor;
                      // cerrar sesión no debe eludirlo desde la cabecera.
                      if (isSectionRoot)
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          onPressed: widget.onSignOut,
                          icon: const Icon(Icons.logout_rounded),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar() => Material(
    color: context.visuals.surfaceLow,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EntrenaWordmark(width: 156),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Text(
              'ADMINISTRACIÓN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.visuals.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder(
              future: _access,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text('No se pudo comprobar el acceso.'),
                      TextButton(
                        onPressed: _retryAccess,
                        child: const Text('Reintentar permisos'),
                      ),
                    ],
                  );
                }
                if (snapshot.data?.admin != true) {
                  return const SizedBox.shrink();
                }
                final sections = _sections.where(
                  (section) =>
                      (!section.guided || widget.hasGuidedPrograms) &&
                      (!section.operations || widget.hasOperations) &&
                      (section.path != '/accounts' || snapshot.data!.accounts),
                );
                String? group;
                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    for (final section in sections) ...[
                      if (group != section.group)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
                          child: Text(
                            group = section.group,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: context.visuals.textMuted),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          key: ValueKey('admin-nav-${section.path}'),
                          selected: section.contains(widget.path),
                          selectedTileColor: context.visuals.accentSoft,
                          selectedColor: Theme.of(context)
                              .colorScheme
                              .secondary,
                          iconColor: context.visuals.textMuted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(section.icon, size: 21),
                          title: Text(section.label),
                          minLeadingWidth: 22,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          onTap: () => _navigate(section.path),
                        ),
                      ),
                    ],
                    Builder(
                      builder: (toolContext) => ListTile(
                        key: const ValueKey('admin-tool-calculator'),
                        leading: const Icon(Icons.speed),
                        title: const Text('Calculadora de ritmos'),
                        onTap: () {
                          _scaffold.currentState?.closeDrawer();
                          ProfessionalToolsWorkspace.openCalculator(
                            toolContext,
                          );
                        },
                      ),
                    ),
                    if (snapshot.data!.accountsFailed)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Acceso a cuentas sin comprobar.'),
                            TextButton(
                              onPressed: _retryAccess,
                              child: const Text('Reintentar permisos'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _EnvironmentLabel(),
          ),
        ],
      ),
    ),
  );
}

class _EnvironmentLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 7, color: context.visuals.warning),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          AppConfig.isDevelopment ? 'Desarrollo' : 'Producción',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    ],
  );
}

class AdminShellScope extends InheritedWidget {
  const AdminShellScope({
    required this.isSectionRoot,
    required super.child,
    super.key,
  });
  final bool isSectionRoot;

  static bool hidesAppBar(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AdminShellScope>()
          ?.isSectionRoot ??
      false;

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) =>
      isSectionRoot != oldWidget.isSectionRoot;
}

class _AdminSection {
  const _AdminSection(
    this.group,
    this.label,
    this.path,
    this.icon, {
    this.guided = false,
    this.operations = false,
  });
  final String group, label, path;
  final IconData icon;
  final bool guided, operations;

  bool contains(String location) =>
      location == path ||
      location.startsWith('$path/') ||
      (path == '/accounts' && location == '/trainers');
}

const _sections = [
  _AdminSection(
    'Inicio',
    'Pendientes',
    '/home',
    Icons.dashboard_outlined,
    operations: true,
  ),
  _AdminSection(
    'Contenido',
    'Programas guiados',
    '/guided-programs',
    Icons.auto_stories_outlined,
    guided: true,
  ),
  _AdminSection(
    'Contenido',
    'Sesiones',
    '/sessions',
    Icons.view_agenda_outlined,
  ),
  _AdminSection(
    'Contenido',
    'Calentamientos',
    '/warmups',
    Icons.self_improvement_rounded,
    guided: true,
  ),
  _AdminSection(
    'Contenido',
    'Ejercicios',
    '/exercises',
    Icons.fitness_center_rounded,
  ),
  _AdminSection(
    'Preparación deportiva',
    'Preparaciones',
    '/programs',
    Icons.account_tree_outlined,
  ),
  _AdminSection(
    'Gestión',
    'Cuentas y Pro',
    '/accounts',
    Icons.manage_accounts_outlined,
  ),
  _AdminSection(
    'Gestión',
    'Calidad del catálogo',
    '/quality',
    Icons.fact_check_outlined,
    operations: true,
  ),
  _AdminSection(
    'Gestión',
    'Historial editorial',
    '/history',
    Icons.history,
    operations: true,
  ),
  _AdminSection(
    'Herramientas',
    'Estado del sistema',
    '/system',
    Icons.monitor_heart_outlined,
    operations: true,
  ),
  _AdminSection(
    'Herramientas',
    'Laboratorio',
    '/laboratory',
    Icons.science_outlined,
  ),
];
