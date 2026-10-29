// Género del catálogo que usa la app. Las colecciones de Firestore y los
// buckets de Storage llevan su prefijo para poder sumar más géneros con la
// misma estructura (reggaeton, rock_pop, salsa, popular).
export const genero = "vallenato";

/// Colección del género: "vallenato_songs", "vallenato_levels"...
export function coleccion(
  nombre: "songs" | "levels" | "privateLevelAnswers" | "intros",
): string {
  return `${genero}_${nombre}`;
}

/// Bucket del género: "vallenato-instrumentos"... (los buckets usan guiones).
export function bucketDe(
  tipo:
    | "instrumentos"
    | "canciones-instrumentales"
    | "canciones-completas"
    | "portadas"
    | "cancion-intro",
): string {
  return `${genero.replaceAll("_", "-")}-${tipo}`;
}
