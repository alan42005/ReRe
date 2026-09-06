import 'package:flutter/material.dart';

class HabitIconHelper {
  static const List<IconData> availableIcons = [
    Icons.fitness_center_rounded,
    Icons.menu_book_rounded,
    Icons.water_drop_rounded,
    Icons.self_improvement_rounded,
    Icons.code_rounded,
    Icons.bedtime_rounded,
    Icons.directions_run_rounded,
    Icons.local_cafe_rounded,
    Icons.star_rounded,
    Icons.favorite_rounded,
  ];

  static IconData getIcon(int code) {
    for (final icon in availableIcons) {
      if (icon.codePoint == code) {
        return icon;
      }
    }
    return Icons.star_rounded;
  }
}
