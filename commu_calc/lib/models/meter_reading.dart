class MeterReading {
  final String date;
  final num lightDay;
  final num lightNight;
  final double heating;
  final num waterHot;
  final num waterCold;

  const MeterReading({
    required this.date,
    required this.lightDay,
    required this.lightNight,
    required this.heating,
    required this.waterHot,
    required this.waterCold,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'lightDay': lightDay,
    'lightNight': lightNight,
    'heating': heating,
    'waterHot': waterHot,
    'waterCold': waterCold,
  };

  factory MeterReading.fromJson(Map<String, dynamic> json) {
    num parseNum(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val;
      return num.tryParse(val.toString().replaceAll(',', '.')) ?? 0;
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString().replaceAll(',', '.')) ?? 0.0;
    }

    return MeterReading(
      date: json['date']?.toString() ?? '',
      lightDay: parseNum(json['lightDay']),
      lightNight: parseNum(json['lightNight']),
      heating: parseDouble(json['heating']),
      waterHot: parseNum(json['waterHot']),
      waterCold: parseNum(json['waterCold']),
    );
  }

  static const MeterReading empty = MeterReading(
    date: '',
    lightDay: 0,
    lightNight: 0,
    heating: 0.0,
    waterHot: 0,
    waterCold: 0,
  );
}

enum MeterType {
  lightDay,
  lightNight,
  heating,
  waterHot,
  waterCold,
}

extension MeterTypeExt on MeterType {
  String get label {
    switch (this) {
      case MeterType.lightDay:
        return 'Свет (День)';
      case MeterType.lightNight:
        return 'Свет (Ночь)';
      case MeterType.heating:
        return 'Отопление';
      case MeterType.waterHot:
        return 'Вода ГВС';
      case MeterType.waterCold:
        return 'Вода ХВС';
    }
  }

  String get unit {
    switch (this) {
      case MeterType.lightDay:
      case MeterType.lightNight:
        return 'кВт⋅ч';
      case MeterType.heating:
        return 'Гкал';
      case MeterType.waterHot:
      case MeterType.waterCold:
        return 'м³';
    }
  }

  bool get isDecimal => this == MeterType.heating;

  num getValue(MeterReading reading) {
    switch (this) {
      case MeterType.lightDay:
        return reading.lightDay;
      case MeterType.lightNight:
        return reading.lightNight;
      case MeterType.heating:
        return reading.heating;
      case MeterType.waterHot:
        return reading.waterHot;
      case MeterType.waterCold:
        return reading.waterCold;
    }
  }
}

class ConsumptionTrend {
  final num currentDelta;
  final num? previousDelta;

  const ConsumptionTrend({
    required this.currentDelta,
    this.previousDelta,
  });

  num? get deltaDiff => previousDelta != null ? currentDelta - previousDelta! : null;

  double? get percentChange {
    if (previousDelta == null || previousDelta! == 0) return null;
    return ((currentDelta - previousDelta!) / previousDelta!) * 100.0;
  }

  bool get isIncreased => (deltaDiff ?? 0) > 0.0001;
  bool get isDecreased => (deltaDiff ?? 0) < -0.0001;
}
