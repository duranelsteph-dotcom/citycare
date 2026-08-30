import '../../domain/entities/search.dart';

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String tripClock(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String tripDateLabel(DateTime at) {
  final local = at.toLocal();
  return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month - 1]}';
}

/// Distance affichée. 0 = incalculable (un seul point), pas une vitesse.
String tripDistanceLabel(double meters) {
  if (meters <= 0) {
    return 'Distance inconnue';
  }
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String tripWindowLabel(Trip trip) {
  return '${tripClock(trip.startedAt)} – ${tripClock(trip.endedAt)}';
}

String tripSubtitle(Trip trip) {
  final points = trip.pointCount == 1 ? '1 position' : '${trip.pointCount} positions';
  return '${tripDistanceLabel(trip.distanceMeters)} · $points';
}
