#!/bin/sh
# Compila el APK de release y lo sube a la release "apk-latest" de GitHub
# (se reemplaza cada vez; enlace de descarga fijo). Ejecutar junto a publicar
# las funciones. Requiere `gh` autenticado (gh auth login).
set -e
PATH="$PATH:/c/Program Files/GitHub CLI" # gh recién instalado puede no estar en el PATH de la terminal
unset GITHUB_TOKEN # un token viejo en el entorno gana sobre el login de `gh auth login`
cd "$(dirname "$0")/.."

sh scripts/build_release.sh \
  --dart-define=SUPABASE_URL=https://btfoclgtqhokqkgbpxmp.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_bdGU9q84AizSHnqrFglH-g_nngqbut0

# El nombre del archivo es el que ve quien lo descarga: riff.apk.
apk=build/app/outputs/flutter-apk/riff.apk
cp build/app/outputs/flutter-apk/app-release.apk "$apk"
fecha=$(date '+%Y-%m-%d %H:%M')
commit=$(git rev-parse --short HEAD)

if gh release view apk-latest >/dev/null 2>&1; then
  gh release upload apk-latest "$apk" --clobber
  gh release delete-asset apk-latest app-release.apk --yes >/dev/null 2>&1 || true # nombre anterior
  gh release edit apk-latest --title "APK $fecha" --notes "Commit $commit"
else
  gh release create apk-latest "$apk" --title "APK $fecha" --notes "Commit $commit" --target main
fi
gh release view apk-latest --json url -q .url
