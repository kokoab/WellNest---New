# Flutter dev setup (WellNest)

Run the backend in Docker, run Flutter on your Mac. No ADB/Docker device setup.

### 1. Install Flutter

```bash
# If you don't have Flutter yet (macOS):
brew install flutter
# Or: https://docs.flutter.dev/get-started/install/macos
```

### 2. Backend must be running

```bash
docker compose up -d
```

Backend URL: **http://localhost:8080** (or **http://localhost** if you mapped port 80).

### 3. Open the frontend project

- **Android Studio**: File → Open → `frontend/src` (the folder that contains `pubspec.yaml`).
- Or **VS Code / Cursor**: Open folder `frontend/src`.

### 4. Run the app

**Chrome (no device/emulator):**

```bash
cd frontend/src
flutter pub get
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8080
```

**Android emulator:**

1. In Android Studio: **Tools → Device Manager** (or **More Actions → Virtual Device Manager**).
2. Create an AVD if needed (e.g. Pixel 6, API 34), then click **Run** (▶) to start it.
3. In terminal (from `frontend/src`):

   ```bash
   flutter devices   # you should see the emulator
   flutter run -d <device-id> --dart-define=BASE_URL=http://10.0.2.2:8080
   ```

   Use `http://10.0.2.2:8080` so the **emulator** (Android) can reach your **Mac's** backend (10.0.2.2 = host from inside the emulator). Use `:80` if your backend is on port 80.

**Physical Android phone:**

1. On the phone: **Settings → About phone** → tap **Build number** 7 times to enable Developer options.
2. **Settings → Developer options** → turn on **USB debugging**.
3. Connect the phone with USB, allow debugging when prompted.
4. On your Mac:

   ```bash
   cd frontend/src
   flutter devices   # phone should appear
   flutter run -d <device-id> --dart-define=BASE_URL=http://<YOUR_MAC_IP>:8080
   ```

   Use your Mac's IP (e.g. `192.168.1.x`) so the phone can reach the backend. Find it: **System Settings → Wi‑Fi → your network → Details**.

---

## Quick reference: BASE_URL

| Where the app runs     | Backend URL to use        |
|------------------------|----------------------------|
| Chrome on Mac          | `http://localhost:8080`    |
| Android emulator       | `http://10.0.2.2:8080`     |
| Physical Android (USB) | `http://<YOUR_MAC_IP>:8080` |

Use `:80` instead of `:8080` if you exposed the backend on port 80.

---

## ADB in a nutshell

- **List devices:** `adb devices`
- **Restart ADB:** `adb kill-server && adb start-server`
- **Enable USB debugging:** Settings → Developer options → USB debugging (see "Physical Android phone" above).

Android Studio's Device Manager and built-in ADB are enough for Flutter development.
