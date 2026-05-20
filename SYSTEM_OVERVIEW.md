# WellNest System Overview

## Overview

WellNest is a Flutter client and a Dockerized Laravel 12 API for recipes, social feed, meal planning, messaging, and an Ollama-powered assistant.

## Frontend

- **Framework:** Flutter (Dart), package name `wellnest`
- **Location:** `frontend/src/`
- **Screens / services / models** under `lib/`

## Backend

- **Framework:** Laravel 12 (PHP 8.4)
- **Location:** `backend/src/laravel/`

### Docker services

| Service | Port | Role |
| ------- | ---- | ---- |
| `backend_nginx` | 8080 | REST API entry |
| `backend_app` | — | PHP-FPM |
| `database` | 3306 | MySQL |
| `reverb` | 8081 (host) | WebSockets (Laravel Reverb) |
| `queue_worker` | — | Broadcast + async jobs |

## Real-time flow

1. Flutter connects to Reverb (`pusher_reverb_flutter`) on port **8081** with Sanctum Bearer auth via `POST /api/broadcasting/auth`.
2. Channels: `private-notifications.{userId}` (`notification.badge.updated`), `private-conversation.{id}` (`message.new`, `assistant.stream`).
3. Laravel stores notifications in the **database**; badge events nudge clients to refetch counts. Chat messages use `NewMessageEvent` (broadcast immediately via `ShouldBroadcastNow`).
4. **`queue_worker` must be running** for queued assistant jobs and any `ShouldBroadcast` events.

See [DOCKER.md](DOCKER.md) for setup and `backend/src/laravel/.env.example` for Reverb keys.
