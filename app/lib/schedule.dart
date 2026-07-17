/// Metro de Lisboa's published service hours: 06:30–01:00, every day of the year.
///
/// Judged against the device clock rather than a real timezone conversion. The
/// app is about the trains under your feet, so for anyone it's built for local
/// time *is* Lisbon time; a proper conversion would mean shipping the tz
/// database to fix a case that doesn't arise.
import 'strings.dart';

const _openMinutes = 6 * 60 + 30; // 06:30 — first trains
const _closeMinutes = 1 * 60; //     01:00 — last trains

/// Service hours, written the way Metro publishes them.
const serviceHours = '06:30 – 01:00';

/// True between the last train and the first: 01:00 → 06:29.
bool metroClosedAt(DateTime now) {
  final m = now.hour * 60 + now.minute;
  return m >= _closeMinutes && m < _openMinutes;
}

bool metroIsClosed() => metroClosedAt(DateTime.now());

String closedTitle() => tr('Metro is closed', 'Metro fechado');

String opensAt() => tr('Opens at 06:30', 'Abre às 06:30');

/// "Metro is closed · opens 06:30" — one line, for tight spots.
String closedLine() => tr('Metro closed · opens 06:30', 'Metro fechado · abre às 06:30');

String scheduleLabel() => tr('Service hours', 'Horário');

String everyDay() => tr('every day', 'todos os dias');
