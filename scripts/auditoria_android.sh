#!/bin/sh
# Comprobador de la auditoría de seguridad (H-01, H-02, H-03, H-06). Uso: sh scripts/auditoria_android.sh
M=android/app/src/main/AndroidManifest.xml
G=android/app/build.gradle.kts
chk() { if eval "$2" >/dev/null 2>&1; then echo "[OK ] $1"; else echo "[FALLA] $1"; fi; }
chk "H-01 script de release con --obfuscate"           "grep -q -- --obfuscate scripts/build_release.sh"
chk "H-01 R8 activo (isMinifyEnabled = true)"            "grep -q 'isMinifyEnabled = true' $G"
chk "H-01 recursos reducidos (isShrinkResources = true)" "grep -q 'isShrinkResources = true' $G"
chk "H-02 allowBackup=false"                             "grep -q 'android:allowBackup=\"false\"' $M"
chk "H-03 usesCleartextTraffic=false"                    "grep -q 'android:usesCleartextTraffic=\"false\"' $M"
chk "H-03 networkSecurityConfig declarado"               "grep -q 'android:networkSecurityConfig' $M"
chk "H-06 release NO firmado con la llave debug"         "! grep -A12 'release {' $G | grep -q 'signingConfigs.getByName(\"debug\")' || grep -q 'key.properties' $G"
