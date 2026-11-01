import { AsyncLocalStorage } from "node:async_hooks";

// Géneros del catálogo. Las colecciones de Firestore llevan su prefijo y cada
// género tiene un solo bucket de Storage con una carpeta por tipo de archivo.
// La app manda el género en cada petición; vallenato es el de siempre.
export const generosReales = [
  "vallenato",
  "reggaeton",
  "rock_pop",
  "salsa",
  "popular",
] as const;
export type GeneroReal = typeof generosReales[number];
// "aleatorio" (Popurrí) no tiene catálogo propio: mezcla los cinco y sus ids
// llevan el género delante ("salsa--facil-03"). Su progreso sí es propio.
export const generos = [...generosReales, "aleatorio"] as const;
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

const separador = "--";

/// Género real e id dentro de su catálogo. En aleatorio el id lo dice
/// ("salsa--facil-03"); en los demás es el género de la petición.
export function partirId(id: string): { genero: GeneroReal; id: string } {
  const genero = generoActual();
  if (genero !== "aleatorio") return { genero, id };
  const corte = id.indexOf(separador);
  const prefijo = id.slice(0, corte);
  if (corte <= 0 || !generosReales.includes(prefijo as GeneroReal)) {
    throw new Error(`Id sin género en Popurrí: ${id}`);
  }
  return { genero: prefijo as GeneroReal, id: id.slice(corte + separador.length) };
}

export const generoDe = (id: string) => partirId(id).genero;
export const idReal = (id: string) => partirId(id).id;

/// Id de [ajeno] (p. ej. la canción de un nivel) en el mismo catálogo que
/// [id]: en aleatorio le pone el género de [id] delante.
export function vecino(id: string, ajeno: string): string {
  return generoActual() === "aleatorio"
    ? `${generoDe(id)}${separador}${ajeno}`
    : ajeno;
}

/// Id visible en aleatorio para el documento [id] del catálogo de [genero].
export function idMezclado(genero: GeneroReal, id: string): string {
  return `${genero}${separador}${id}`;
}

type Catalogo = "songs" | "levels" | "privateLevelAnswers" | "intros";

/// Colección del género: "vallenato_songs", "reggaeton_levels"...
export function coleccion(
  nombre: Catalogo,
  genero: GeneroReal = generoActual() as GeneroReal,
): string {
  return `${genero}_${nombre}`;
}

/// Ruta del documento [id] del catálogo [nombre], también en aleatorio.
export function enCatalogo(nombre: Catalogo, id: string): string {
  const { genero, id: real } = partirId(id);
  return `${coleccion(nombre, genero)}/${real}`;
}

/// Subcolección del jugador para el género: vallenato conserva los nombres
/// de siempre ("progress") para no perder el progreso guardado; los demás
/// llevan prefijo ("reggaeton_progress", "aleatorio_progress").
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
  genero: GeneroReal = generoActual() as GeneroReal,
): { bucket: string; ruta: string } {
  const slug = genero.replaceAll("_", "-");
  const carpeta = tipo === "intro" ? `intro_${slug}` : tipo;
  return { bucket: slug, ruta: `${carpeta}/${ruta}` };
}
