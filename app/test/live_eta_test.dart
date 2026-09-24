// The client-side ETA re-aging that keeps arrival countdowns live (#60).
import 'package:flutter_test/flutter_test.dart';
import 'package:metro_lisboa_ar/stations_panel.dart' show agedEta, fmtEta;

void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  group('agedEta', () {
    test('counts down from the fetch time', () {
      expect(agedEta(120, t0, t0), 120);
      expect(agedEta(120, t0, t0.add(const Duration(seconds: 30))), 90);
      expect(agedEta(120, t0, t0.add(const Duration(seconds: 119))), 1);
    });

    test('never goes negative once the train has passed', () {
      expect(agedEta(20, t0, t0.add(const Duration(seconds: 60))), 0);
    });
  });

  test('fmtEta formats mm:ss', () {
    expect(fmtEta(0), '0:00');
    expect(fmtEta(90), '1:30');
    expect(fmtEta(605), '10:05');
  });
}
