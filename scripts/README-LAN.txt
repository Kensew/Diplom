# Запуск по Wi-Fi (ПК + телефон)

Скрипты в папке `scripts\` поднимают PocketBase и Flutter так, чтобы телефон в **той же Wi-Fi сети** подключался к серверу на ПК.

## Быстрый старт

1. **Сервер (ПК + телефон):** двойной щелчок `start-server.bat` в корне проекта  
   или `scripts\start-server.bat` — один PocketBase для `127.0.0.1` и Wi-Fi.
2. **Один раз (от администратора):** `5-open-firewall-pocketbase.bat` — если телефон не видит сервер.
3. **Телефон — USB:** `3-run-on-phone.bat`
4. **Телефон — APK:** `4-build-apk-lan.bat`

Для браузера на ПК отдельно: `2-start-flutter-web-lan.bat` или `start-all-lan.bat`.

## Файлы

| Файл | Назначение |
|------|------------|
| **`start-server.bat`** | **Один сервер для ПК и телефона (Wi-Fi)** |
| `_config.bat` | Пути к проекту и PocketBase |
| `1-start-pocketbase-lan.bat` | То же, что start-server (альias) |
| `2-start-flutter-web-lan.bat` | Flutter Web в Edge |
| `3-run-on-phone.bat` | `flutter run` на Android по USB |
| `4-build-apk-lan.bat` | Release APK с IP вашего ПК |
| `5-open-firewall-pocketbase.bat` | Правило брандмауэра |
| `start-all-lan.bat` | PocketBase + Web в двух окнах |

## Важно

- IP определяется автоматически (обычно `192.168.x.x`). Он показывается при запуске bat-файла.
- В APK адрес **зашивается при сборке**. Сменился IP — пересоберите `4-build-apk-lan.bat` или используйте `3-run-on-phone.bat`.
- Проверка с телефона: в браузере телефона откройте `http://ВАШ_IP:8090/api/health` — должно быть `{"message":"API is healthy.",...}`.
- Путь к PocketBase: папка `pocketbase\` в корне проекта (скачайте `pocketbase.exe` туда).

## Тестовые аккаунты

Пароль: `12345678` — `customer@test.ru`, `executor@test.ru`, `support@test.ru`.
