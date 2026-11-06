#!/bin/sh
# Compila el APK de release y lo sube a la release "apk-latest" de GitHub
# (se reemplaza cada vez; enlace de descarga fijo). Ejecutar junto a publicar
# las funciones. Requiere `gh` autenticado (gh auth login).
set -e
PATH="$PATH:/c/Program Files/GitHub CLI" # gh recién instalado puede no estar en el PATH de la terminal
cd "$(dirname "$0")/.."

sh scripts/build_release.sh \
  --dart-define=SUPABASE_URL=https://hwjvwabvuavkexgibzps.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_R2OsMivFieugYs48edAydA_pCVvSNzM

apk=build/app/outputs/flutter-apk/app-release.apk
fecha=$(date '+%Y-%m-%d %H:%M')
commit=$(git rev-parse --short HEAD)

if gh release view apk-latest >/dev/null 2>&1; then
  gh release upload apk-latest "$apk" --clobber
  gh release edit apk-latest --title "APK $fecha" --notes "Commit $commit"
else
  gh release create apk-latest "$apk" --title "APK $fecha" --notes "Commit $commit" --target main
fi
gh release view apk-latest --json url -q .url
