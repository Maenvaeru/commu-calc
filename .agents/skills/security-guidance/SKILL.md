---
name: security-guidance
description: Vulnerability scanning, injection defense, credential leak prevention, path traversal checks and policy gating. Use when reviewing code security, designing network boundaries or verifying unsafe operations.
---

# 🛡️ Security Guidance & Defensive Engineering

Автоматический аудит безопасности, перехват уязвимостей до коммита, защита от утечек секретов и построение защитных барьеров.
Основано на стандартах Anthropic `security-guidance` и спецификациях HOL Guard / ArmorCodex.

## Главные векторы аудита (Zero-Trust)

### 1. Инъекции и выполнение команд (Injection / RCE)
- **Запрет `eval()`, небезопасного `Function()`, `child_process.exec()` со склейкой строк.**
- Использовать строго параметризованные вызовы: `execFile()`, `spawn()` с массивом аргументов без шелла (`shell: false`).
- Обязательная санитизация пользовательских строк перед передачей в CLI/SQL.

### 2. Path Traversal & File System Safety
- Запрет неконтролируемой конкатенации путей вида `path.join(root, userInput)`.
- Обязательная проверка: резолвленный путь обязан начинаться с корневой директории:
  ```javascript
  const target = path.resolve(root, userInput);
  if (!target.startsWith(path.resolve(root))) throw new Error("Path traversal blocked");
  ```
- Запрет на запись вне рабочей области проекта (Zero-Write outside workspace).

### 3. XSS & DOM Security (UI / Webview)
- Никогда не использовать `innerHTML` с неэкранированными данными из внешних источников.
- Использовать `textContent`, `setAttribute()` или безопасные DOM-билдеры.
- Строгая изоляция контекстов Electron (Context Isolation, Disable Node Integration в Webview).

### 4. Утечки секретов и учетных данных (Credential Guard)
- Запрет на хардкод API-ключей, токенов, паролей в коде и репозитории.
- Проверка `.gitignore` на наличие файлов конфигураций (`.env`, `tokens.json`, `creds/`).
- Автоматическая маскировка чувствительных полей в логах и артефактах.

### 5. Circuit Breakers & Watchdogs
- Любой внешний запрос (HTTP, IPC, процесс) обязан иметь жесткий таймаут (`AbortSignal.timeout(ms)`).
- Идемпотентность повторных вызовов.
- Graceful degradation: система обязана сохранять работоспособность при падении внешнего сервиса.
