// Género del catálogo que usa la app. Las colecciones de Firestore llevan su
// prefijo y cada género tiene un solo bucket de Storage con una carpeta por
// tipo de archivo, para sumar más géneros con la misma estructura
// (reggaeton, rock_pop, salsa, popular).
export const genero = "vallenato";

/// Colección del género: "vallenato_songs", "vallenato_levels"...
export function coleccion(
  nombre: "songs" | "levels" | "privateLevelAnswers" | "intros",
): string {
  return `${genero}_${nombre}`;
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
): { bucket: string; ruta: string } {
  const slug = genero.replaceAll("_", "-");
  const carpeta = tipo === "intro" ? `intro_${slug}` : tipo;
  return { bucket: slug, ruta: `${carpeta}/${ruta}` };
}
