# WellNest System Overview

## Overview
WellNest is a modern application consisting of a Flutter-based frontend and a containerized Laravel (PHP) backend. The system is designed with a clear separation of concerns, utilizing a REST API and WebSockets for communication between the client and server.

## Frontend
- **Framework:** Flutter (Dart)
- **Location:** `frontend/src/`
- **Architecture:** 
  - **Screens:** UI components like `admin_dashboard.dart` and `admin_login_screen.dart`.
  - **Widgets:** Reusable UI elements such as `master_user_table.dart`.
  - **Services:** Handles external API communication (`api_service.dart`, `recipe_service.dart`).
  - **Models:** Data structures mapping JSON responses to Dart objects (`admin_user.dart`).

## Backend
- **Framework:** Laravel (PHP)
- **Location:** `backend/src/laravel/`
- **Infrastructure:** Docker & Docker Compose (`docker-compose.yml`)

### Docker Services
The backend is composed of several specialized microservices to ensure scalability and performance:
1. **backend_nginx:** The Nginx web server acting as the main entry point (port 8080), handling incoming HTTP requests and serving the Laravel application.
2. **backend_app:** A PHP-FPM container running the core Laravel application logic.
3. **database:** A MySQL 8.0 instance handling persistent data storage with a dedicated volume (`db_data`).
4. **reverb:** Laravel Reverb WebSocket server (port 8081) enabling real-time, bi-directional communication for events and broadcasting.
5. **queue_worker:** A background worker running Laravel's queue system to process asynchronous jobs, broadcasts, and notifications.

## Network & Data Flow
1. The **Flutter Frontend** makes HTTP REST API requests to the Nginx server (`backend_nginx`), which forwards them to the PHP-FPM service (`backend_app`).
2. The **Laravel Application** queries the **MySQL Database** for necessary data and returns the response.
3. For real-time functionality, the frontend subscribes to the **Reverb WebSocket** server. When the Laravel application dispatches an event, the **Queue Worker** processes it and broadcasts it through Reverb to connected clients.
