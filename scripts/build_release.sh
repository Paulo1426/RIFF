#!/bin/sh
# H-01: build de release con el código Dart ofuscado. Guarda build/symbols para leer los stack traces.
# Solo arm64 (casi todos los teléfonos desde 2017): el APK pesa ~1/3 que con las tres arquitecturas.
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols "$@"
