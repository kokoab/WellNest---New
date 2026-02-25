#!/usr/bin/env bash
# Run the app with backend URL set. Usage:
#   ./run.sh              → use default device, default BASE_URL (emulator)
#   ./run.sh chrome       → run on Chrome (BASE_URL=localhost:8080)
#   ./run.sh <device-id>  → run on that device (default BASE_URL)

set -e
cd "$(dirname "$0")"

DEVICE="${1:-}"
if [[ "$DEVICE" == "chrome" ]]; then
  flutter run -d chrome --dart-define=BASE_URL=http://localhost:8080
elif [[ -n "$DEVICE" ]]; then
  flutter run -d "$DEVICE" --dart-define=BASE_URL=http://10.0.2.2:8080
else
  # No args: use default device and default BASE_URL (already 10.0.2.2:8080 in app_config.dart)
  flutter run
fi
