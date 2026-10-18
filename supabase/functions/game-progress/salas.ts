// "Desafía a tus amigos": salas de hasta maxJugadoresSala personas que juegan
// las mismas canciones. Contrarreloj: 5 minutos, gana quien sume más puntos.
// Eliminación: sin tiempo; en cada ronda sale el último en adivinar.

export const modosSala = ["contrarreloj", "eliminacion"] as const;
export type ModoSala = typeof modosSala[number];

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
