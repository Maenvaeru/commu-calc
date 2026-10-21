import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/meter_reading.dart';

class GasClient {
  final String scriptUrl;
  final Duration timeout;

  GasClient({
    this.scriptUrl = 'https://script.google.com/macros/s/AKfycbyiU9eX7H-d4PUToq2laCsLiEwpmevQUiIHydURzfBkpF9xyxHW4Pczwm4uhVJhYUtT/exec',
    this.timeout = const Duration(seconds: 8),
  });

  Future<List<MeterReading>> fetchHistory() async {
    final request = http.Request('GET', Uri.parse(scriptUrl))..followRedirects = true;
    final streamedResponse = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Ошибка сервера (HTTP ${response.statusCode})');
    }

    if (response.body.contains('Sign in - Google Accounts')) {
      throw Exception('401: Доступ ограничен. Настройте "Доступ: Все" в Google Apps Script.');
    }

    final decoded = json.decode(response.body);
    if (decoded is Map && decoded['error'] != null) {
      throw Exception('Ошибка Google Sheets: ${decoded['error']}');
    }

    if (decoded is Map && decoded['history'] is List) {
      final List<dynamic> list = decoded['history'];
      return list.map((item) => MeterReading.fromJson(Map<String, dynamic>.from(item))).toList();
    }

    if (decoded is Map) {
      return [MeterReading.fromJson(Map<String, dynamic>.from(decoded))];
    }

    return [];
  }

  Future<void> sendReading(MeterReading reading) async {
    final request = http.Request('POST', Uri.parse(scriptUrl))
      ..headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json'})
      ..body = json.encode(reading.toJson())
      ..followRedirects = true;

    final streamedResponse = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('HTTP ${response.statusCode} при отправке в GAS');
    }

    if (response.body.contains('Sign in - Google Accounts')) {
      throw Exception('401: Доступ ограничен. Опубликуйте скрипт с правами "Все".');
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['status'] == 'error') {
        throw Exception(decoded['message'] ?? 'Сбой сохранения в таблице');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Сбой сохранения')) rethrow;
      // Если тело не JSON, но статус 200/302, проверим на HTML
      if (response.body.trim().startsWith('<')) {
        throw Exception('Скрипт вернул неожиданную HTML-страницу ошибки');
      }
    }
  }
}
