import 'package:flutter_test/flutter_test.dart';
import 'package:plant_watering/esp32_api.dart';

void main() {
  test('PlantStatus parses ESP32 JSON', () {
    final s = PlantStatus.fromJson({
      'moisture': 42,
      'raw': 2100,
      'pump': true,
      'auto': false,
      'threshold': 35,
      'pumpRemainingMs': 5000,
      'cooldownRemainingMs': 0,
    });
    expect(s.moisture, 42);
    expect(s.pump, isTrue);
    expect(s.auto, isFalse);
    expect(s.pumpRemainingMs, 5000);
  });
}
