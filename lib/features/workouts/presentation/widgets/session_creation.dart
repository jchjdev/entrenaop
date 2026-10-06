import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre el selector común; ambos accesos reutilizan los editores existentes.
Future<String?> chooseSessionEditor(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Qué sesión quieres crear?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.fitness_center_rounded),
                title: const Text('Fuerza y acondicionamiento'),
                onTap: () => sheetContext.pop('/plan/library/new'),
              ),
              ListTile(
                leading: const Icon(Icons.directions_run_rounded),
                title: const Text('Carrera'),
                subtitle: const Text('Continua, series o pirámide por tramos'),
                onTap: () => sheetContext.pop('/plan/library/new-running'),
              ),
            ],
          ),
        ),
      ),
    );
