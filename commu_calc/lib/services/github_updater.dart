import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ReleaseInfo {
  final String tagName;
  final String title;
  final String notes;
  final String apkAssetUrl;
  final int apkSize;

  ReleaseInfo({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.apkAssetUrl,
    required this.apkSize,
  });
}

class GitHubUpdater {
  static const String currentVersion = '1.0.2';
  static const String owner = 'Maenvaeru';
  static const String repo = 'commu-calc';
  static const String token = '';
  static const MethodChannel _channel = MethodChannel('com.example.commu_calc/updater');

  static Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'CommuCalc-App',
        if (token.isNotEmpty) 'Authorization': 'token $token',
      };

  static Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final res = await http.get(url, headers: _headers).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        debugPrint('Updater HTTP check: ${res.statusCode}');
        return null;
      }

      final data = json.decode(res.body);
      if (data is! Map) return null;

      final tagName = data['tag_name']?.toString() ?? '';
      if (!isNewerVersion(tagName, currentVersion)) {
        return null;
      }

      final assets = data['assets'];
      String? apkUrl;
      int size = 0;

      if (assets is List) {
        for (final item in assets) {
          final name = item['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = item['browser_download_url']?.toString() ?? item['url']?.toString();
            size = (item['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      if (apkUrl == null) return null;

      return ReleaseInfo(
        tagName: tagName,
        title: data['name']?.toString() ?? tagName,
        notes: data['body']?.toString() ?? '',
        apkAssetUrl: apkUrl,
        apkSize: size,
      );
    } catch (e) {
      debugPrint('Check for update error: $e');
      return null;
    }
  }

  static bool isNewerVersion(String remoteTag, String localVer) {
    try {
      final cleanRemote = remoteTag.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanLocal = localVer.replaceAll(RegExp(r'[^0-9.]'), '');

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = cleanLocal.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (lParts.length < 3) {
        lParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isApkAlreadyDownloaded(ReleaseInfo release) async {
    try {
      final targetFile = File('${Directory.systemTemp.path}/commu_calc_update.apk');
      if (await targetFile.exists()) {
        final length = await targetFile.length();
        if (release.apkSize > 0 && (length == release.apkSize || length > 40000000)) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canRequestInstall() async {
    if (!Platform.isAndroid) return true;
    final res = await _channel.invokeMethod<bool>('canRequestInstall');
    return res ?? true;
  }

  static Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openInstallSettings');
  }

  static Future<String> launchInstaller() async {
    if (!Platform.isAndroid) return 'INSTALLED';
    final targetFile = File('${Directory.systemTemp.path}/commu_calc_update.apk');
    if (!await targetFile.exists()) {
      return 'FILE_NOT_FOUND';
    }
    final res = await _channel.invokeMethod<String>('installApk', {'filePath': targetFile.path});
    return res ?? 'UNKNOWN';
  }

  static Future<String> downloadAndInstall(
    ReleaseInfo release, {
    required Function(double progress, int received, int total) onProgress,
  }) async {
    final tempDir = Directory.systemTemp;
    final targetFile = File('${tempDir.path}/commu_calc_update.apk');

    // 1. Проверка локального кэша (Zero Waste)
    if (await isApkAlreadyDownloaded(release)) {
      onProgress(1.0, release.apkSize, release.apkSize);
      return await launchInstaller();
    }

    http.Client? client;
    try {
      final tmpFile = File('${tempDir.path}/commu_calc_update.apk.tmp');

      if (await tmpFile.exists()) await tmpFile.delete();
      if (await targetFile.exists()) await targetFile.delete();

      client = http.Client();
      final request = http.Request('GET', Uri.parse(release.apkAssetUrl));
      request.headers.addAll({
        'Accept': 'application/octet-stream',
        'User-Agent': 'CommuCalc-App',
        if (token.isNotEmpty) 'Authorization': 'token $token',
      });

      final response = await client.send(request);
      if (response.statusCode != 200 && response.statusCode != 302) {
        throw Exception('Ошибка скачивания ассета: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? release.apkSize;
      int downloaded = 0;

      final sink = tmpFile.openWrite();
      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(downloaded / contentLength, downloaded, contentLength);
        }
      }
      await sink.flush();
      await sink.close();

      if (contentLength > 0 && downloaded < (contentLength * 0.95)) {
        throw Exception('Файл скачан не полностью ($downloaded из $contentLength байт)');
      }

      await tmpFile.rename(targetFile.path);

      return await launchInstaller();
    } catch (e) {
      debugPrint('Update download failure: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }
}
