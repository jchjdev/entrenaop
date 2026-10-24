import 'package:flutter/material.dart';
import 'package:workout_editor_ui/running_pace_calculator_view.dart';

class RunningPaceCalculatorPage extends StatelessWidget {
  const RunningPaceCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calculadora de ritmos')),
    body: const RunningPaceCalculatorView(),
  );
}
