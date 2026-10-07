import 'package:flutter/material.dart';

class HomeSectionHeading extends StatelessWidget {
  const HomeSectionHeading({super.key, required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final heading = Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
    final action = this.action;
    if (action == null) return heading;
    if (MediaQuery.textScalerOf(context).scale(14) > 21) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          Align(alignment: Alignment.centerRight, child: action),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        action,
      ],
    );
  }
}
