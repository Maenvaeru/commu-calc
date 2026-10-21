import 'package:flutter_test/flutter_test.dart';
import 'package:commu_calc/models/meter_reading.dart';
import 'package:commu_calc/services/meter_storage.dart';
import 'package:commu_calc/services/github_updater.dart';

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

    test('MeterConsumptionBreakdown calculates past (M-1) and pre-past (M-2) consumption correctly', () async {
      final storage = MeterStorage();
      await storage.load();

      // Light Day: last=3917 (21.02), prev=3758 (21.01), prePrev=3601 (22.12)
      final breakdown = MeterConsumptionBreakdown.calculate(
        type: MeterType.lightDay,
        lastReading: storage.lastReading,
        previousReading: storage.previousReading,
        prePreviousReading: storage.prePreviousReading,
        currentInputVal: 4080,
      );

      // Past consumption (январь -> февраль): 3917 - 3758 = 159
      expect(breakdown.previousMonthConsumption, 159);

      // Pre-past consumption (декабрь -> январь): 3758 - 3601 = 157
      expect(breakdown.prePreviousMonthConsumption, 157);

      // Current consumption (февраль -> сейчас): 4080 - 3917 = 163
      expect(breakdown.currentConsumption, 163);

      // Dynamics: 163 - 159 = +4 к прошлому месяцу (+2.5%)
      expect(breakdown.deltaDiff, 4);
      expect(breakdown.isIncreased, isTrue);
      expect(breakdown.percentChange, closeTo(2.5, 0.1));
    });

    test('MeterConsumptionBreakdown handles decimal heating consumption correctly', () async {
      final storage = MeterStorage();
      await storage.load();

      // Heating: last=4.249 (21.02), prev=3.555 (21.01), prePrev=2.9183 (22.12)
      final breakdown = MeterConsumptionBreakdown.calculate(
        type: MeterType.heating,
        lastReading: storage.lastReading,
        previousReading: storage.previousReading,
        prePreviousReading: storage.prePreviousReading,
        currentInputVal: 4.8000,
      );

      // Past: 4.249 - 3.555 = 0.694
      expect(breakdown.previousMonthConsumption, 0.694);

      // Pre-past: 3.555 - 2.9183 = 0.6367
      expect(breakdown.prePreviousMonthConsumption, 0.6367);

      // Current: 4.8000 - 4.2490 = 0.551
      expect(breakdown.currentConsumption, 0.551);

      // Diff: 0.551 - 0.694 = -0.143 (economy!)
      expect(breakdown.deltaDiff, -0.143);
      expect(breakdown.isDecreased, isTrue);
    });

    test('GitHubUpdater version comparison logic prevents loops', () {
      expect(GitHubUpdater.isNewerVersion('v1.0.2', '1.0.1'), isTrue);
      expect(GitHubUpdater.isNewerVersion('v1.0.1', '1.0.1'), isFalse);
      expect(GitHubUpdater.isNewerVersion('v1.0.0', '1.0.1'), isFalse);
      expect(GitHubUpdater.isNewerVersion('v1.0.1', '1.0.2'), isFalse);
    });
  });
}
