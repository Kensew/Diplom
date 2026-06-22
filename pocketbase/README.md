# PocketBase backend (v0.38.2)

This folder contains the project database and migrations.

## First run on a new PC

1. Download PocketBase 0.38.2 for Windows amd64 from https://pocketbase.io/docs/
2. Extract `pocketbase.exe` into this folder (`pocketbase/pocketbase.exe`)
3. Run from project root: `start-server.bat`

Migrations in `pb_migrations/` are applied automatically on first start if needed.
Demo data and avatars are already in `pb_data/`.

## Admin

Open http://127.0.0.1:8090/_/ after starting the server.

## Test accounts (password: 12345678)

- customer@test.ru
- executor@test.ru
- support@test.ru
