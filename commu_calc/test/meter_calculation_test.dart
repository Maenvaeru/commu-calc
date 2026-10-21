import 'package:flutter_test/flutter_test.dart';
import 'package:commu_calc/models/meter_reading.dart';
import 'package:commu_calc/services/meter_storage.dart';

void main() {
  group('MeterReading & ConsumptionTrend tests', () {
    test('Calculates current delta correctly for integer meters', () {
      const trend = ConsumptionTrend(currentDelta: 165, previousDelta: 159);
      expect(trend.currentDelta, 165);
      expect(trend.deltaDiff, 6);
      expect(trend.isIncreased, isTrue);
      expect(trend.isDecreased, isFalse);
      expect(trend.percentChange, closeTo(3.77, 0.01));
    });

    test('Calculates economy when consumption decreased', () {
      const trend = ConsumptionTrend(currentDelta: 150, previousDelta: 160);
      expect(trend.deltaDiff, -10);
      expect(trend.isDecreased, isTrue);
      expect(trend.isIncreased, isFalse);
      expect(trend.percentChange, closeTo(-6.25, 0.01));
    });

    test('Handles decimal heating calculations without precision loss', () {
      // 4.249 -> 4.900 (delta = 0.651) vs previous delta (4.249 - 3.555 = 0.694)
      const trend = ConsumptionTrend(currentDelta: 0.651, previousDelta: 0.694);
      expect(trend.deltaDiff, closeTo(-0.043, 0.001));
      expect(trend.isDecreased, isTrue);
    });

    test('MeterStorage default seed matches расчеты.txt', () async {
      final storage = MeterStorage();
      final history = await storage.load();
      expect(history.length, greaterThanOrEqualTo(4));
      
      final last = storage.lastReading;
      expect(last.date, '21.02.26');
      expect(last.lightDay, 3917);
      expect(last.lightNight, 1609);
      expect(last.heating, 4.249);
      expect(last.waterHot, 173);
      expect(last.waterCold, 225);

      final prev = storage.previousReading;
      expect(prev, isNotNull);
      expect(prev!.date, '21.01.26');
      expect(prev.lightDay, 3758);

      // Verify past delta for Light Day
      final pastDelta = last.lightDay - prev.lightDay;
      expect(pastDelta, 159);
    });
  });
}
