import 'dart:convert';
import 'dart:io';
import '../models/meter_reading.dart';

class MeterStorage {
  static const String _fileName = 'commu_calc_history.json';

  // 10 реальных строк со скриншота Google Таблицы COMMU-CALC
  static final List<MeterReading> _seedHistory = [
    const MeterReading(
      date: '21.09.26',
      lightDay: 4991,
      lightNight: 2023,
      heating: 5.365,
      waterHot: 197,
      waterCold: 265,
    ),
    const MeterReading(
      date: '21.08.26',
      lightDay: 4828,
      lightNight: 1970,
      heating: 5.365,
      waterHot: 197,
      waterCold: 259,
    ),
    const MeterReading(
      date: '21.07.26',
      lightDay: 4670,
      lightNight: 1913,
      heating: 5.365,
      waterHot: 191,
      waterCold: 253,
    ),
    const MeterReading(
      date: '21.06.26',
      lightDay: 4518,
      lightNight: 1841,
      heating: 5.365,
      waterHot: 188,
      waterCold: 247,
    ),
    const MeterReading(
      date: '20.05.26',
      lightDay: 4367,
      lightNight: 1775,
      heating: 5.365,
      waterHot: 184,
      waterCold: 241,
    ),
    const MeterReading(
      date: '22.04.26',
      lightDay: 4224,
      lightNight: 1723,
      heating: 5.149,
      waterHot: 181,
      waterCold: 236,
    ),
    const MeterReading(
      date: '20.03.26',
      lightDay: 4054,
      lightNight: 1658,
      heating: 4.721,
      waterHot: 176,
      waterCold: 230,
    ),
    const MeterReading(
      date: '21.02.26',
      lightDay: 3917,
      lightNight: 1609,
      heating: 4.249,
      waterHot: 173,
      waterCold: 225,
    ),
    const MeterReading(
      date: '21.01.26',
      lightDay: 3758,
      lightNight: 1554,
      heating: 3.555,
      waterHot: 170,
      waterCold: 221,
    ),
    const MeterReading(
      date: '22.12.25',
      lightDay: 3601,
      lightNight: 1491,
      heating: 2.918,
      waterHot: 166,
      waterCold: 216,
    ),
  ];

  List<MeterReading> _history = [];

  List<MeterReading> get history => List.unmodifiable(_history);

  MeterReading get lastReading => _history.isNotEmpty ? _history.first : _seedHistory.first;

  MeterReading? get previousReading => _history.length > 1 ? _history[1] : (_seedHistory.length > 1 ? _seedHistory[1] : null);

  MeterReading? get prePreviousReading => _history.length > 2 ? _history[2] : (_seedHistory.length > 2 ? _seedHistory[2] : null);

  static DateTime parseReadingDate(String dateStr) {
    try {
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      }
      final clean = dateStr.split(' ').first.trim();
      final parts = clean.split('.');
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        var year = int.tryParse(parts[2]) ?? 2026;
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(2020);
  }

  static String normalizeDateDisplay(String dateStr) {
    final dt = parseReadingDate(dateStr);
    if (dt.year < 2000) return dateStr;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = (dt.year % 100).toString().padLeft(2, '0');
    return '$d.$m.$y';
  }

  File _getLocalFile() {
    return File(_fileName);
  }

  Future<List<MeterReading>> load() async {
    List<MeterReading> loaded = [];
    try {
      final file = _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = json.decode(content);
          loaded = list.map((item) => MeterReading.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (_) {
      // Игнорируем сбой ФС
    }

    final Map<String, MeterReading> map = {};
    for (final s in _seedHistory) {
      map[normalizeDateDisplay(s.date)] = s;
    }
    for (final item in loaded) {
      map[normalizeDateDisplay(item.date)] = item;
    }

    _history = map.values.toList();
    _history.sort((a, b) => parseReadingDate(b.date).compareTo(parseReadingDate(a.date)));
    return _history;
  }

  Future<void> save(List<MeterReading> newHistory) async {
    _history = List.from(newHistory);
    _history.sort((a, b) => parseReadingDate(b.date).compareTo(parseReadingDate(a.date)));
    try {
      final file = _getLocalFile();
      final jsonStr = json.encode(_history.map((r) => r.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (_) {
      // Игнорируем сбой ФС
    }
  }

  Future<void> addReading(MeterReading reading) async {
    final normDate = normalizeDateDisplay(reading.date);
    final normalized = MeterReading(
      date: normDate,
      lightDay: reading.lightDay,
      lightNight: reading.lightNight,
      heating: reading.heating,
      waterHot: reading.waterHot,
      waterCold: reading.waterCold,
    );

    final Map<String, MeterReading> map = {};
    map[normDate] = normalized;
    for (final item in _history) {
      final d = normalizeDateDisplay(item.date);
      if (!map.containsKey(d)) {
        map[d] = item;
      }
    }

    _history = map.values.toList();
    _history.sort((a, b) => parseReadingDate(b.date).compareTo(parseReadingDate(a.date)));
    await save(_history);
  }

  void mergeFromRemote(List<MeterReading> remoteList) {
    if (remoteList.isEmpty) return;
    final Map<String, MeterReading> map = {};
    for (final item in _history) {
      map[normalizeDateDisplay(item.date)] = item;
    }
    for (final item in remoteList) {
      final normDate = normalizeDateDisplay(item.date);
      map[normDate] = MeterReading(
        date: normDate,
        lightDay: item.lightDay,
        lightNight: item.lightNight,
        heating: item.heating,
        waterHot: item.waterHot,
        waterCold: item.waterCold,
      );
    }
    _history = map.values.toList();
    _history.sort((a, b) => parseReadingDate(b.date).compareTo(parseReadingDate(a.date)));
    save(_history);
  }
}
