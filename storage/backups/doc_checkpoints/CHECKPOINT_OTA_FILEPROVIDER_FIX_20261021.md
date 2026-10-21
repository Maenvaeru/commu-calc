# Checkpoint: Android OTA FileProvider Fix & UTF-8 Release Encoding (v1.0.4)
- Дата: 2026-10-21
- Версия: v1.0.4
- DevLog: 28 правил | Hot Tier: ~8.3 КБ

## 1. Ликвидированные проблемы и корневые причины
1. **Сбой установки `PlatformException: Failed to find configured root that contains .../code_cache/...`:**
   - Root Cause: В Flutter `Directory.systemTemp` на Android ссылается на `codeCacheDir`, который не покрывался списком `<paths>` в `file_paths.xml`.
   - Решение: Переход на `path_provider.getTemporaryDirectory()` (`context.cacheDir`), добавление `<root-path name="root" path="."/>` и канонизация пути файла `apkFile.canonicalFile` в Kotlin.
2. **Знаки вопроса в описании релиза на экране телефона (`????? ? ?????`):**
   - Root Cause: PowerShell 5.1 в `tools/publish_release.ps1` отправлял тело запроса в системной кодировке без заголовка `charset=utf-8`.
   - Решение: Преобразование в массив байтов UTF-8 через `[System.Text.Encoding]::UTF8.GetBytes()` и добавление `Content-Type: application/json; charset=utf-8`.
3. **Отсутствие запасного пути установки:**
   - Решение: В диалог обновления добавлена резервная кнопка прямого перехода к скачиванию через браузер.
4. **Скрытый дефект кэша `length > 40000000`:**
   - Решение: Заменено на строгое совпадение `length == release.apkSize` с удалением поврежденных или старых файлов при несовпадении.

## 2. Матрица верификации (QA Proof)
- `flutter test`: 10/10 тестов пройдено.
- `flutter analyze`: 0 замечаний (No issues found).
- Релизный APK: `commu-calc.apk` (49,254,064 байт / 46.97 МБ).
