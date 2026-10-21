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
      const trend = ConsumptionTrend(currentDelta: 0.651, previousDelta: 0.694);
      expect(trend.deltaDiff, closeTo(-0.043, 0.001));
      expect(trend.isDecreased, isTrue);
    });

    test('MeterStorage default seed matches 10 real months with September 2026 base', () async {
      final storage = MeterStorage();
      final history = await storage.load();
      expect(history.length, 10);
      
      final last = storage.lastReading;
      expect(last.date, '21.09.26');
      expect(last.lightDay, 4991);
      expect(last.lightNight, 2023);
      expect(last.heating, 5.365);
      expect(last.waterHot, 197);
      expect(last.waterCold, 265);

      final prev = storage.previousReading;
      expect(prev, isNotNull);
      expect(prev!.date, '21.08.26');
      expect(prev.lightDay, 4828);
      expect(prev.lightNight, 1970);
      expect(prev.heating, 5.365);
      expect(prev.waterHot, 197);
      expect(prev.waterCold, 259);

      final prePrev = storage.prePreviousReading;
      expect(prePrev, isNotNull);
      expect(prePrev!.date, '21.07.26');
      expect(prePrev.lightDay, 4670);
      expect(prePrev.lightNight, 1913);
      expect(prePrev.heating, 5.365);
      expect(prePrev.waterHot, 191);
      expect(prePrev.waterCold, 253);

      // Verify past delta for Light Day: 4991 - 4828 = 163
      expect(last.lightDay - prev.lightDay, 163);
    });

    test('User screenshot case: Light Day 5147 produces 156 kWh (-7 kWh / -4.3% economy)', () async {
      final storage = MeterStorage();
      await storage.load();

      // Light Day: last=4991 (21.09.26), prev=4828 (21.08.26), prePrev=4670 (21.07.26)
      final breakdown = MeterConsumptionBreakdown.calculate(
        type: MeterType.lightDay,
        lastReading: storage.lastReading,
        previousReading: storage.previousReading,
        prePreviousReading: storage.prePreviousReading,
        currentInputVal: 5147,
      );

      // Current consumption: 5147 - 4991 = 156
      expect(breakdown.currentConsumption, 156);

      // Past consumption (август -> сентябрь): 4991 - 4828 = 163
      expect(breakdown.previousMonthConsumption, 163);

      // Pre-past consumption (июль -> август): 4828 - 4670 = 158
      expect(breakdown.prePreviousMonthConsumption, 158);

      // Dynamics: 156 - 163 = -7 kWh (-4.3%) -> economy!
      expect(breakdown.deltaDiff, -7);
      expect(breakdown.isDecreased, isTrue);
      expect(breakdown.isIncreased, isFalse);
      expect(breakdown.percentChange, closeTo(-4.3, 0.1));
    });

    test('User screenshot case: Light Night 2079 produces 56 kWh (+3 kWh / +5.7%)', () async {
      final storage = MeterStorage();
      await storage.load();

      // Light Night: last=2023 (21.09), prev=1970 (21.08), prePrev=1913 (21.07)
      final breakdown = MeterConsumptionBreakdown.calculate(
        type: MeterType.lightNight,
        lastReading: storage.lastReading,
        previousReading: storage.previousReading,
        prePreviousReading: storage.prePreviousReading,
        currentInputVal: 2079,
      );

      // Current: 2079 - 2023 = 56
      expect(breakdown.currentConsumption, 56);

      // Past: 2023 - 1970 = 53
      expect(breakdown.previousMonthConsumption, 53);

      // Pre-past: 1970 - 1913 = 57
      expect(breakdown.prePreviousMonthConsumption, 57);

      // Dynamics: 56 - 53 = +3
      expect(breakdown.deltaDiff, 3);
      expect(breakdown.isIncreased, isTrue);
      expect(breakdown.percentChange, closeTo(5.7, 0.1));
    });

    test('User screenshot case: Heating 5.800 produces 0.435 Gcal against summer zero', () async {
      final storage = MeterStorage();
      await storage.load();

      // Heating: last=5.365 (21.09), prev=5.365 (21.08), prePrev=5.365 (21.07)
      final breakdown = MeterConsumptionBreakdown.calculate(
        type: MeterType.heating,
        lastReading: storage.lastReading,
        previousReading: storage.previousReading,
        prePreviousReading: storage.prePreviousReading,
        currentInputVal: 5.800,
      );

      // Current: 5.800 - 5.365 = 0.435
      expect(breakdown.currentConsumption, 0.435);

      // Past summer: 5.365 - 5.365 = 0.0
      expect(breakdown.previousMonthConsumption, 0.0);

      // Diff: 0.435 - 0.0 = 0.435
      expect(breakdown.deltaDiff, 0.435);
      expect(breakdown.isIncreased, isTrue);
    });

    test('Date Chronology Engine correctly parses and formats dates', () {
      final dtIso = MeterStorage.parseReadingDate('2026-09-21T06:13:56.000Z');
      expect(dtIso.year, 2026);
      expect(dtIso.month, 9);
      expect(dtIso.day, 21);

      expect(MeterStorage.normalizeDateDisplay('2026-09-21T06:13:56.000Z'), '21.09.26');
      expect(MeterStorage.normalizeDateDisplay('21.09.2026 9:13:56'), '21.09.26');
      expect(MeterStorage.normalizeDateDisplay('21.09.26'), '21.09.26');

      final dateA = MeterStorage.parseReadingDate('21.09.26');
      final dateB = MeterStorage.parseReadingDate('21.02.26');
      expect(dateA.isAfter(dateB), isTrue);
    });

    test('GitHubUpdater version comparison logic prevents loops', () {
      expect(GitHubUpdater.isNewerVersion('v1.0.3', '1.0.2'), isTrue);
      expect(GitHubUpdater.isNewerVersion('v1.0.2', '1.0.2'), isFalse);
      expect(GitHubUpdater.isNewerVersion('v1.0.1', '1.0.2'), isFalse);
      expect(GitHubUpdater.isNewerVersion('v1.0.0', '1.0.2'), isFalse);
    });
  });
}
