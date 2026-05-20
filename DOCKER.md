# WellNest – Running with Docker

## Start the full stack

From the project root:

```bash
docker compose up -d
```

| Service | Host port | Purpose |
| ------- | --------- | ------- |
| `backend_nginx` | **8080** | HTTP API (`http://localhost:8080`) |
| `reverb` | **8081** | WebSocket (maps container **8080** → host **8081**) |
| `database` | 3306 | MySQL 8.0 |
| `queue_worker` | — | Processes queued jobs (`message.new`, assistant replies) |
| `backend_app` | — | PHP-FPM (Laravel) |

Set `REVERB_APP_KEY`, `REVERB_APP_SECRET`, and `REVERB_APP_ID` in the project root `.env` (see `backend/src/laravel/.env.example`). Flutter must use the same `REVERB_APP_KEY` via `--dart-define=REVERB_APP_KEY=...`.

**Real-time chat requires** `queue_worker` and `reverb` to be running. Badge updates (`notification.badge.updated`) broadcast immediately; chat events are queued then delivered by the worker.

## Database migrations, storage link, and seed

```bash
docker compose exec backend_app php artisan migrate --force
docker compose exec backend_app php artisan storage:link
docker compose exec backend_app php artisan db:seed --force
```

- `--force` is required in non-interactive environments.
- **Recipe ingredients** are name-only (`recipe_ingredients` has no `quantity` / `unit` columns). That requires migration `2026_05_20_000001_drop_quantity_unit_from_recipe_ingredients_table`. If `migrate` prints *Nothing to migrate*, that migration has already run. On a **fresh** database, `migrate` runs all migrations in order (create table, then drop those columns) before you seed.
- User uploads live under `backend/storage/app/public/` (gitignored). Run `storage:link` on new machines.

## Default admin credentials (after seeding)

| Field        | Value               |
| ------------ | ------------------- |
| **Email**    | `admin@example.com` |
| **Password** | `password`          |

## Default test user (regular user)

| Field        | Value              |
| ------------ | ------------------ |
| **Email**    | `test@example.com` |
| **Password** | `password`         |

## Real email for password resets

Configure in `backend/src/laravel/.env`, then restart `backend_app` and `queue_worker`:

```bash
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_gmail_app_password
MAIL_FROM_ADDRESS=your_email@gmail.com
MAIL_FROM_NAME="WellNest"
```

## Run tests in Docker

```bash
docker compose exec backend_app ./vendor/bin/phpunit
```
