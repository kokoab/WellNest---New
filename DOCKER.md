# WellNest – Running with Docker

## Start the backend

From the project root:

```bash
docker compose up -d database backend_app backend_nginx
```

API base: **http://localhost:8080**

## Database migrations and seed

Run migrations (and seed) inside the app container:

```bash
docker compose exec backend_app php artisan migrate --force
docker compose exec backend_app php artisan db:seed --force
```

- `--force` is needed when not in interactive mode (e.g. CI/Docker).

## Default admin credentials (after seeding)

After running `php artisan db:seed`, you can sign in to the **admin** app with:

| Field    | Value              |
|----------|--------------------|
| **Email**    | `admin@example.com` |
| **Password** | `password`          |

Use these on the **Admin Login** screen in the Flutter app. Change the password in production or create a new admin and remove this account.

## Default test user (regular user)

| Field    | Value              |
|----------|--------------------|
| **Email**    | `test@example.com`  |
| **Password** | `password`          |

Used for the normal (non-admin) login flow.
