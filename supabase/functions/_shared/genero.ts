import { AsyncLocalStorage } from "node:async_hooks";

// Géneros del catálogo. Las colecciones de Firestore llevan su prefijo y cada
// género tiene un solo bucket de Storage con una carpeta por tipo de archivo.
// La app manda el género en cada petición; vallenato es el de siempre.
export const generos = [
  "vallenato",
  "reggaeton",
  "rock_pop",
  "salsa",
  "popular",
] as const;
export type Genero = typeof generos[number];

export function esGenero(valor: unknown): valor is Genero {
  return generos.includes(valor as Genero);
}

// Género de la petición en curso: cada petición corre en su propio contexto,
// así dos jugadores de géneros distintos no se pisan.
const actual = new AsyncLocalStorage<Genero>();

/// Corre [fn] con [genero] como género actual (vallenato si no es válido;
/// quien lee el cuerpo responde 400 en ese caso).
export function conGenero<T>(genero: unknown, fn: () => T): T {
  return actual.run(esGenero(genero) ? genero : "vallenato", fn);
}

export function generoActual(): Genero {
  return actual.getStore() ?? "vallenato";
}

/// Colección del género: "vallenato_songs", "reggaeton_levels"...
export function coleccion(
  nombre: "songs" | "levels" | "privateLevelAnswers" | "intros",
  genero: Genero = generoActual(),
): string {
  return `${genero}_${nombre}`;
}

/// Subcolección del jugador para el género: vallenato conserva los nombres
/// de siempre ("progress") para no perder el progreso guardado; los demás
/// llevan prefijo ("reggaeton_progress").
export function coleccionJugador(
  nombre: string,
  genero: Genero = generoActual(),
): string {
  return genero === "vallenato" ? nombre : `${genero}_${nombre}`;
}

export type TipoAudio =
  | "instrumentos"
  | "canciones-instrumentales"
  | "canciones-completas"
  | "intro";

/// Bucket del género y ruta dentro de la carpeta de [tipo]:
/// ("vallenato", "instrumentos/cancion-001/bateria.mp3"). Las intros van en
/// la carpeta "intro_vallenato". Los buckets usan guiones ("rock-pop").
export function ubicacion(
  tipo: TipoAudio,
  ruta: string,
  genero: Genero = generoActual(),
): { bucket: string; ruta: string } {
  const slug = genero.replaceAll("_", "-");
  const carpeta = tipo === "intro" ? `intro_${slug}` : tipo;
  return { bucket: slug, ruta: `${carpeta}/${ruta}` };
}
