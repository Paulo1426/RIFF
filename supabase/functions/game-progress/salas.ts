// "Desafía a tus amigos": salas de hasta maxJugadoresSala personas que juegan
// las mismas canciones. Contrarreloj: 5 minutos, gana quien sume más puntos.
// Eliminación: sin tiempo; en cada ronda sale el último en adivinar.

export const modosSala = ["contrarreloj", "eliminacion"] as const;
export type ModoSala = typeof modosSala[number];

// Instrumentos: el juego principal. Intros: las de "Adivina la intro".
export const tiposSala = ["instrumentos", "intros"] as const;
export type TipoSala = typeof tiposSala[number];

// Fichas: moneda propia de las salas, distinta de las monedas de intros.
// Se ganan en salas de instrumentos y se gastan para crear o entrar a una de
// intros (se devuelven si sales antes de que empiece).
export const precioSalaIntros = 5;
export const premiosPorPuesto = [10, 7, 3] as const;

/// Fichas para los tres primeros de [clasificados] (ya ordenados). No cobra
/// premio quien abandonó ni quien no acertó ninguna canción, para que no se
/// puedan ganar fichas entrando y saliendo con otra cuenta.
export function premiosSala(
  clasificados: readonly { uid: string; aciertos: number; abandono: boolean }[],
): Record<string, number> {
  return Object.fromEntries(
    clasificados
      .filter((jugador) => !jugador.abandono && jugador.aciertos > 0)
      .slice(0, premiosPorPuesto.length)
      .map((jugador, puesto) => [jugador.uid, premiosPorPuesto[puesto]]),
  );
}

// Se guarda en cada sala (maxJugadores) para poder ampliarlo sin migrar.
export const maxJugadoresSala = 5;
export const duracionContrarrelojMs = 5 * 60_000;

// Sin 0/O ni 1/I/L para que el código se pueda dictar sin confusiones.
const alfabetoCodigo = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const largoCodigo = 6;

export function generarCodigo(
  aleatorio: (maxExclusivo: number) => number,
): string {
  let codigo = "";
  for (let i = 0; i < largoCodigo; i++) {
    codigo += alfabetoCodigo[aleatorio(alfabetoCodigo.length)];
  }
  return codigo;
}

export function codigoValido(valor: unknown): valor is string {
  return typeof valor === "string" &&
    new RegExp(`^[${alfabetoCodigo}]{${largoCodigo}}$`).test(valor);
}

/// Puntos de un acierto en contrarreloj: 100 base, hasta 50 por rapidez
/// (se pierde 1 cada 6 s) y 1 por cada $10.000 sin gastar.
export function puntosAcierto(
  segundos: number,
  presupuestoRestante: number,
): number {
  const rapidez = Math.max(0, 50 - Math.floor(Math.max(0, segundos) / 6));
  return 100 + rapidez + Math.floor(Math.max(0, presupuestoRestante) / 10_000);
}

/// Eliminación: cuando todos los vivos menos uno adivinaron, ese uno sale.
export function eliminadoDeRonda(
  vivos: readonly string[],
  acertaron: readonly string[],
): string | null {
  const pendientes = vivos.filter((uid) => !acertaron.includes(uid));
  return vivos.length > 1 && pendientes.length === 1 ? pendientes[0] : null;
}

/// Canción de la posición [indice]; si se acaban, vuelve a empezar la lista.
export function nivelDeIndice(levelIds: readonly string[], indice: number) {
  return levelIds[indice % levelIds.length];
}
