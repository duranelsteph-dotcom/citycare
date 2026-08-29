import 'package:flutter/material.dart';

import '../../domain/entities/zones.dart';

const weekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String shortTime(String value) {
  if (value.length >= 5) {
    return value.substring(0, 5);
  }
  return value;
}

String scheduleSummary(SafetyZone zone) {
  if (zone.schedules.isEmpty) {
    return 'Aucune plage horaire';
  }
  final grouped = <String, List<int>>{};
  for (final item in zone.schedules) {
    final key = '${shortTime(item.startTime)}–${shortTime(item.endTime)}';
    grouped.putIfAbsent(key, () => []).add(item.weekday);
  }
  return grouped.entries.map((entry) {
    final days = [...entry.value]..sort();
    final labels = days.map((day) => weekdayLabels[day]).join(', ');
    return '$labels ${entry.key}';
  }).join(' · ');
}

String apiTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00';
}

TimeOfDay parseApiTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}
