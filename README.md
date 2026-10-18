<p align="center">
  <img src="lib/assets/images/logo/riff_logo.png" alt="Logo de RIFF" width="320">
</p>

<h1 align="center">RIFF</h1>

<p align="center">
  Juego móvil de adivinar canciones escuchándolas instrumento por instrumento.
  <br>
  Flutter · Firebase · Supabase
</p>

---

## ¿Qué es RIFF?

RIFF es un juego musical inspirado en el vallenato y la música colombiana. Cada
nivel es una canción separada en pistas por instrumento (*stems*): batería,
acordeón, bajo y guitarra. El jugador tiene un presupuesto para comprar
instrumentos, los escucha por separado o mezclados y debe adivinar qué canción
es.

<p align="center">
  <img src="lib/assets/images/portada/login.png" alt="Portada de inicio de sesión" width="420">
</p>

<!--
Capturas de pantalla: guárdalas en docs/screenshots/ y descomenta esta tabla.

| Inicio | Partida | Canción adivinada | Adivina la intro |
|:-:|:-:|:-:|:-:|
| <img src="docs/screenshots/home.png" width="180"> | <img src="docs/screenshots/partida.png" width="180"> | <img src="docs/screenshots/ganada.png" width="180"> | <img src="docs/screenshots/intros.png" width="180"> |
-->

## Cómo se juega

1. **Elige una dificultad**: Fácil, Media o Avanzada. Cada una tiene cinco
   niveles; al completarlos se desbloquea la siguiente.
2. **Compra instrumentos**: empiezas con **$1.000.000** y puedes comprar tres
   de los cuatro instrumentos. El precio de cada uno se revela al comprarlo
   ($300.000 o $400.000) y las tres compras suman exactamente el presupuesto.
3. **Escucha**: cada instrumento comprado reproduce su pista. Puedes oírlos por
   separado o mezclados. Los fragmentos duran 30 segundos.
4. **Encuentra la melodía**: tras la tercera compra, la melodía queda en uno de
   los instrumentos. Si la compraste, se desbloquean las cuatro pistas y la
   mezcla instrumental. Si quedó en el instrumento que no compraste, tienes que
   adivinar solo con lo que tienes.
5. **Adivina la canción**: escribe el nombre. Si aciertas, se desbloquea la
   grabación original con voz en el mini reproductor y se guarda tu progreso.

Cada vez que repites un nivel, los precios y la melodía cambian.

### Modo extra: Adivina la intro

Cada nivel adivinado por primera vez da monedas: 2 en Fácil, 3 en Media y 4 en
Avanzada. Cada moneda saca una carta con la intro de una canción al azar, que
también hay que adivinar. Con los 15 niveles se ganan las 45 monedas que cuestan
todas las intros.

## Características

- **Inicio de sesión** con correo y contraseña, Google o modo invitado (el
  invitado no guarda progreso entre sesiones).
- **Reglas en el servidor**: precios, melodía, respuestas y progreso se
  deciden en Supabase Edge Functions, no en el teléfono. La app no puede ver la
  respuesta ni el instrumento de la melodía.
- **Modo sin conexión**: los audios se guardan en caché al reproducirlos y el
  progreso local se sincroniza al recuperar internet.
- **Interfaz "liquid glass"** con animaciones, transiciones entre pantallas y
  música de fondo en los menús.

## Tecnologías

| Parte | Tecnología |
| --- | --- |
| App | Flutter / Dart 3, Riverpod |
| Inicio de sesión | Firebase Authentication |
| Catálogo y progreso | Cloud Firestore |
| Lógica del juego | Supabase Edge Functions (`game-progress`, `audio-link`) |
| Audios | Supabase Storage |
| Reproducción | just_audio, audio_session |

## Estructura

```text
lib/
  screens/     pantallas (inicio, partida, intros, instrucciones)
  widgets/     componentes de UI (liquid glass, reproductor)
  animations/  animaciones
  services/    repositorios, audio, almacenamiento offline
  models/      Nivel, Partida, Instrumento, Usuario
  providers/   providers de Riverpod
supabase/functions/
  game-progress/  niveles, partidas, compras, respuestas y monedas
  audio-link/     enlaces temporales a los audios autorizados
scripts/       carga de niveles e intros en Firestore
```

## Ejecutar el proyecto

Necesitas Flutter, un proyecto de Firebase y uno de Supabase. La configuración
completa (colecciones, secretos y reglas) está en
[FIREBASE_SETUP.md](./FIREBASE_SETUP.md), y las reglas detalladas del juego en
[LOGICA_DEL_JUEGO.md](./LOGICA_DEL_JUEGO.md).

Desplegar el backend (con los secretos ya configurados en Supabase Dashboard):

```powershell
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase functions deploy game-progress
supabase functions deploy audio-link
```

Ejecutar la app con la URL y la clave anon pública de Supabase:

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

El juego no abre hasta que haya niveles publicados en Firestore con el formato
de `FIREBASE_SETUP.md`. La respuesta de cada canción va en
`privateLevelAnswers`, nunca dentro del documento del nivel.

## Plataformas

Android e iOS. Firebase no está configurado para web ni escritorio.
