# WellNest – Project Setup & Error Log (commit_01)

This document records how the WellNest project was set up, its structure, and the errors encountered and fixed during initial configuration.

---

## 1. Project Overview

**WellNest** is a full-stack app with:
- **Backend:** Laravel (PHP) served by PHP-FPM + Nginx
- **Frontend:** Flutter (mobile/web)
- **Database:** MySQL 8.0
- **Infrastructure:** Docker Compose

Target environment: macOS (Apple Silicon) for local development.

---

## 2. Project Structure

```
WellNest/
├── .env                          # Root env (DB, APP_*, etc.)
├── .gitignore
├── commit_01.md                  # This file
├── docker-compose.yml            # Orchestrates all services
│
├── backend/
│   ├── Dockerfile                # PHP 8.4-FPM image
│   ├── nginx/
│   │   └── default.conf          # Nginx vhost (root, PHP-FPM)
│   ├── src/
│   │   └── laravel/              # Laravel app root
│   │       ├── app/
│   │       ├── bootstrap/
│   │       ├── config/
│   │       ├── database/
│   │       ├── public/           # Web root
│   │       ├── resources/
│   │       ├── routes/
│   │       │   ├── api.php
│   │       │   └── web.php
│   │       └── ...
│   └── storage/                  # Laravel storage (mounted)
│       ├── framework/
│       │   ├── cache/
│       │   ├── sessions/
│       │   └── views/
│       └── logs/
│
└── frontend/
    ├── FLUTTER_SETUP.md          # Flutter dev guide
    ├── run.sh                    # Convenience run script
    └── src/                      # Flutter app root
        ├── lib/
        │   ├── config/
        │   │   └── app_config.dart   # BASE_URL, etc.
        │   └── main.dart
        └── pubspec.yaml
```

**Important detail:** Laravel lives in `backend/src/laravel/`, not directly in `backend/src/`. That affects paths in Docker and Nginx.

---

## 3. Docker Compose Architecture

| Service       | Image/Build              | Role                            | Ports   |
|---------------|--------------------------|---------------------------------|---------|
| database      | mysql:8.0                | MySQL                           | 3306    |
| backend_app   | backend/Dockerfile       | PHP-FPM (Laravel)               | 9000    |
| backend_nginx | nginx:alpine             | HTTP server, proxies PHP to FPM | 8080→80 |

- **Network:** All services use `backend`.
- **Backend URL:** `http://localhost:8080` (or `http://localhost` if mapped to 80).

---

## 4. Errors Encountered & Fixes

### 4.1 Backend – Artisan "Could not open input file: artisan"

**Error:**
```text
Could not open input file: artisan
```

**Cause:** `working_dir` was `/var/www`, but Laravel (and `artisan`) lives in `backend/src/laravel/`, so at runtime it’s `/var/www/laravel/`.

**Fix:**
- Set `working_dir: /var/www/laravel` for `backend_app`
- Point storage volume to Laravel’s storage: `./backend/storage:/var/www/laravel/storage`
- Set Nginx root to `/var/www/laravel/public`

---

### 4.2 Backend – PHP Version Mismatch

**Error:**
```text
Your Composer dependencies require a PHP version ">= 8.4.0". You are running 8.2.30.
```

**Fix:** Change the base image in `backend/Dockerfile` from `php:8.2-fpm` to `php:8.4-fpm`.

---

### 4.3 Backend – .env Not Found for Laravel

**Error:**
```text
file_get_contents(/var/www/laravel/.env): Failed to open stream: No such file or directory
```

**Cause:** Laravel expects a `.env` at its root; the project uses a root `.env`, and the Laravel app in the container didn’t have its own.

**Fix:** Copy the root `.env` to `backend/src/laravel/.env` so Laravel has a `.env` at its root. (Cannot mount root `.env` directly inside an already-mounted directory.)

---

### 4.4 Backend – Database Host "database" Not Found

**Error:**
```text
php_network_getaddresses: getaddrinfo for database failed: Name or service not known
```

**Cause:** The `database` service was only on the default network; `backend_app` is on the `backend` network, so it couldn’t resolve `database`.

**Fix:** Add `networks: - backend` to the `database` service in `docker-compose.yml`.

---

### 4.5 Backend – Nginx "File Not Found"

**Cause:** Nginx `root` was `/var/www/public`, but the Laravel app is under `/var/www/laravel/`, so the correct web root is `/var/www/laravel/public`.

**Fix:** In `backend/nginx/default.conf`, set:
```nginx
root /var/www/laravel/public;
```

---

### 4.6 Backend – Invalid Cache Path (View Compiler)

**Error:**
```text
InvalidArgumentException: Please provide a valid cache path.
```

**Cause:** Laravel needs writable dirs for Blade views (`storage/framework/views`, `cache`, `sessions`). The mounted `backend/storage` had only `logs/` and lacked `framework/views`, `framework/cache`, `framework/sessions`.

**Fix:**
1. Create `backend/storage/framework/views`, `cache/data`, `sessions` (plus `.gitkeep` if needed)
2. Run inside the container: `chown -R www-data:www-data /var/www/laravel/storage /var/www/laravel/bootstrap/cache`
3. Clear caches: `php artisan config:clear`, `php artisan view:clear`

---

### 4.7 Flutter – Dart SDK Version Mismatch

**Error:**
```text
Because my_app requires SDK version ^3.11.0, version solving failed.
The current Dart SDK version is 3.10.7.
```

**Fix:** In `frontend/src/pubspec.yaml`, relax the constraint from `^3.11.0` to `^3.10.0` to allow Dart 3.10.x, or upgrade Flutter so it ships Dart 3.11+.

---

### 4.8 Port Mapping – Why 8080 Instead of 80?

**Mapping:** `ports: - "8080:80"` means host port **8080** maps to container port **80**.

To use port 80 on the host, use `ports: - "80:80"`. Port 80 can conflict with other services (Apache, etc.).

---

### 4.9 Accidental .env Push to GitHub

**Issue:** `.env` and other sensitive or generated files were committed and pushed.

**Fix:**
1. Add/update `.gitignore` for `.env`, `vendor/`, `.idea/`, `backend/src/.composer/`, etc.
2. Remove from tracking: `git rm --cached .env`, etc., then commit and push
3. Rotate secrets (APP_KEY, DB password, etc.) because they may be in history
4. Optionally rewrite history with `git filter-repo` or `git filter-branch` to remove `.env` from past commits, then force-push

---

## 5. Flutter Development Workflow

**Recommended:** Run Flutter on the host, backend in Docker.

- **Backend:** `docker compose up -d`
- **Frontend:** From `frontend/src`, run `flutter run -d chrome` or `flutter run -d emulator-5554`

**BASE_URL:**
- Emulator: `http://10.0.2.2:8080`
- Chrome on host: `http://localhost:8080`

---

## 6. Commands Cheatsheet

```bash
# Start all services
docker compose up -d

# Artisan commands
docker compose exec backend_app php artisan migrate
docker compose exec backend_app php artisan key:generate

# Flutter (host)
cd frontend/src
flutter pub get
flutter run -d chrome
flutter run -d emulator-5554

# Rebuild images
docker compose build --no-cache backend_app
```

---

## 7. Lessons Learned

1. **Laravel in a subdir:** Paths in Docker and Nginx must reflect `backend/src/laravel/`.
2. **Networks:** Services that talk to each other must share a network (e.g. `backend`).
3. **Storage mounts:** A separate `backend/storage` mount replaces Laravel’s built-in `storage/`; its structure must exist and be writable.
4. **Secrets:** Keep `.env` out of version control; rotate secrets if they were ever committed.

---

*Document generated from initial setup session. Last updated: February 2026.*
