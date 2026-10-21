import 'dart:convert';
import 'dart:io';
import '../models/meter_reading.dart';

class MeterStorage {
  static const String _fileName = 'commu_calc_history.json';

  static final List<MeterReading> _seedHistory = [
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
      heating: 2.9183,
      waterHot: 166,
      waterCold: 216,
    ),
    const MeterReading(
      date: '20.11.25',
      lightDay: 3419,
      lightNight: 1424,
      heating: 2.3118,
      waterHot: 162,
      waterCold: 210,
    ),
  ];

  List<MeterReading> _history = [];

  List<MeterReading> get history => List.unmodifiable(_history);

  MeterReading get lastReading => _history.isNotEmpty ? _history.first : _seedHistory.first;

  MeterReading? get previousReading => _history.length > 1 ? _history[1] : (_seedHistory.length > 1 ? _seedHistory[1] : null);

  MeterReading? get prePreviousReading => _history.length > 2 ? _history[2] : (_seedHistory.length > 2 ? _seedHistory[2] : null);

  File _getLocalFile() {
    return File(_fileName);
  }

  Future<List<MeterReading>> load() async {
    try {
      final file = _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = json.decode(content);
          _history = list.map((item) => MeterReading.fromJson(Map<String, dynamic>.from(item))).toList();
          if (_history.isNotEmpty) {
            return _history;
          }
        }
      }
    } catch (_) {
      // Fallback на начальные данные при ошибке чтения файла
    }
    _history = List.from(_seedHistory);
    return _history;
  }

  Future<void> save(List<MeterReading> newHistory) async {
    _history = List.from(newHistory);
    try {
      final file = _getLocalFile();
      final jsonStr = json.encode(_history.map((r) => r.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (_) {
      // Игнорируем сбой ФС, в памяти данные сохранены
    }
  }

  Future<void> addReading(MeterReading reading) async {
    _history.insert(0, reading);
    await save(_history);
  }

  void mergeFromRemote(List<MeterReading> remoteList) {
    if (remoteList.isEmpty) return;
    final Map<String, MeterReading> byDate = {};
    for (final item in remoteList) {
      if (item.date.isNotEmpty) byDate[item.date] = item;
    }
    for (final item in _history) {
      if (!byDate.containsKey(item.date)) {
        byDate[item.date] = item;
      }
    }
    _history = byDate.values.toList();
    save(_history);
  }
}
