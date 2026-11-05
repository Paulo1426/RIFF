#!/bin/sh
# H-01: build de release con el código Dart ofuscado. Guarda build/symbols para leer los stack traces.
flutter build apk --release --obfuscate --split-debug-info=build/symbols "$@"
