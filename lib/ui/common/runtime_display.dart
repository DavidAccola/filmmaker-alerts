import 'package:flutter/material.dart';

class RuntimeDisplay extends StatelessWidget {
  final int runtime; // In minutes
  final bool isUpcoming;
  final TextStyle? style;

  const RuntimeDisplay({
    super.key,
    required this.runtime,
    this.isUpcoming = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (runtime == 0) {
      if (isUpcoming) {
        return Text('TBA', style: style);
      } else {
        return const SizedBox.shrink();
      }
    }

    final hours = runtime ~/ 60;
    final minutes = runtime % 60;

    String text = '';
    if (hours > 0) {
      text += '${hours}h ';
    }
    if (minutes > 0 || hours == 0) {
      text += '${minutes}m';
    }

    return Text(text.trim(), style: style);
  }
}
