# Development Log (Hot Tier)

## Ошибочные шаги и грабли (Banned Antipatterns)
1. **[Android / Network]:** Режим Release блокирует сетевые вызовы без разрешения. -> Обязательно `<uses-permission android:name="android.permission.INTERNET"/>` в `AndroidManifest.xml`.
2. **[Windows / UI Blur]:** `BackdropFilter` с большим размытием роняет FPS до 30 на Windows Desktop. -> Запрещен общий blur экрана, использовать `RadialGradient` свечение.
3. **[Flutter / FadeTransition]:** Привязка `_fadeController.forward()` только к успешному коду ответа оставляет экран невидимым при сбое сети. -> Запуск анимации строго в `finally` блоке.
4. **[GAS / Permissions]:** Деплой Web App без прав "Anyone" отдает HTML страницу логина Google вместо JSON. -> Развертывание строго "Execute as: Me", "Who has access: Anyone", проверка `!response.body.contains("Sign in - Google Accounts")`.
5. **[GAS / Silent Failure]:** Слепое доверие HTTP 200/302 при POST запросе и очистка контроллеров стирает данные пользователя при сбое GAS. -> Проверять JSON `{status: "ok"}` или `{status: "success"}` перед очисткой полей.
6. **[Flutter 3.41 / Deprecations]:** `Color.withOpacity()` устарел и ведет к потере точности. -> Использовать строго `.withValues(alpha: ...)`.
7. **[Flutter / Path]:** Команда `flutter` не в системном PATH. -> Использовать прямой вызов `D:\WORK\flutter\bin\flutter.bat`.
8. **[UI / Input Loss]:** Очистка текстовых полей до подтверждения успешной записи локально или на сервере. -> Запрещена очистка до подтвержденного сохранения в LocalStorage.
9. **[Flutter Test / ListView]:** Элементы `ListView` вне стандартного тестового вьюпорта 800x600 не рендерятся. -> Задавать `tester.view.physicalSize = const Size(1080, 2400)` в `widget_test.dart`.
10. **[Flutter UI / Zero Delay]:** Инициализация стейта со спиннером `_isLoading = true` блокирует показ кэша при старте. -> `_isLoading = false` по умолчанию, показ кэша/seed данных мгновенно.
11. **[Android / Gradle Wrapper]:** Отсутствие `distributionUrl` в `gradle-wrapper.properties` ломает `assembleRelease`. -> Фиксировать `distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip`.
12. **[Android / OTA Install]:** Android 8+ блокирует установку APK без `REQUEST_INSTALL_PACKAGES` и `FileProvider`. -> Настраивать `FileProvider` в манифесте и вызывать `Intent.ACTION_VIEW` с `FLAG_GRANT_READ_URI_PERMISSION`.
13. **[GitHub / Private Asset 302]:** Приватный релиз GitHub редиректит на S3. -> Заголовок `Authorization` передавать на `api.github.com` и отсекать при редиректе на AWS.
14. **[GAS 401 Unauthorized]:** GET/POST возвращал HTML авторизации. Причина: доступ не "Anyone". Решение: новое развертывание с открытым доступом.
15. **[Пустой экран при сбое]:** Opacity 0 оставалась при ошибке. Причина: `forward()` только в `if (200)`. Решение: перенос в `finally`.
16. **[Просадки FPS на Windows]:** Лаги при драге окна. Причина: `BackdropFilter 50px`. Решение: замена на `RadialGradient`.
17. **[SocketException на Android]:** Красная полоса ошибки на телефоне. Причина: отсутствие INTERNET permission. Решение: добавлен пермишен в Manifest.
18. **[Тест MyApp broken]:** `test/widget_test.dart` искал класс `MyApp`. Причина: переименование в `CommuCalcApp`. Решение: актуализация имени в тесте.
19. **[Widget test pumpAndSettle timeout]:** Тест падал по таймауту. Причина: бесконечный спиннер или фоновый HTTP без мока. Решение: явный pump(700ms) и локальный кэш.
20. **[Widget test ListView offscreen]:** Не найден виджет «Вода ХВС». Причина: экран 800x600 обрезал карточку. Решение: расширение тестового вьюпорта до 1080x2400.
21. **[Gradle wrapper missing distributionUrl]:** Сборка APK падала с `No value with key distributionUrl`. Причина: пустая строка в файле. Решение: прописан URL Gradle 8.11.1-all.
22. **[Flutter UI / Mobile Overflow]:** Вложенный `Row` с непереносимым текстом дельты в заголовке карточки вызывает горизонтальный `RenderFlex` оверфлоу на экранах <360dp. -> Использовать `Expanded` для заголовка и компактный бейдж `Было: X (±Y)`.
23. **[GitHub API / Empty Repo 422]:** Создание релиза через `POST /repos/{owner}/{repo}/releases` возвращает `422 Repository is empty`, если в репозитории нет коммитов и ветки по умолчанию. -> Сначала выполнить initial commit и `git push -u origin main`.
24. **[GitHub Push Protection / Secret Scan]:** Git push отклоняется (GH013), если коммит содержит hardcoded PAT token (`ghp_...`). -> Хранить токен локально в `.github_token` (в `.gitignore`), передавать через переменные окружения, в клиенте использовать открытый API для публичных репозиториев без передачи секрета.
25. **[Android / FileProvider Grant Permission]:** На прошивках MIUI, HyperOS, OneUI системный установщик не может прочитать APK без явного `Context.grantUriPermission(pkg, apkUri, FLAG_GRANT_READ_URI_PERMISSION)` в цикле по активити установщика. -> Выдавать гранты через `queryIntentActivities`.
26. **[OTA / Download Idempotency & Version Gate]:** Повторное скачивание 47 МБ при каждом клике исключается проверкой размера локального файла (`targetFile.length() == release.apkSize`) и строгой сверкой версий (`isNewerVersion`). -> Использовать локальный кэш перед отправкой запроса на скачивание.
27. **[GAS / Single Object Contract & Real Base]:** Веб-скрипт возвращает плоский JSON последней строки без массива `history`. -> Парсер обязан поддерживать как единичный объект, так и массив, нормализуя дату в ISO/DD.MM.YY и объединяя с полной цепочкой реальных месяцев с сентябрьской базой (21.09.26: 4991/2023/5.365/197/265).
28. **[Android / FileProvider code_cache vs cacheDir & UTF-8 REST Encoding]:** `Directory.systemTemp` в Dart VM резолвится в `code_cache`, не покрываемый стандартным `cache-path` в `file_paths.xml` (падение `PlatformException: Failed to find configured root`). -> Использовать `path_provider.getTemporaryDirectory()` (`context.cacheDir`), добавлять `<root-path name="root" path="."/>` и `apkFile.canonicalFile`. В PowerShell REST запросах отправлять UTF-8 байты с заголовком `charset=utf-8` во избежание знаков вопроса.

## Зафиксированные инциденты и решения
