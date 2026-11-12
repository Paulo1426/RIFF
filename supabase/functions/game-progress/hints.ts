// Configuración y utilidades del sistema de pistas (comodines) del juego.

/// Pistas que se compran. "random" revela al azar una de [randomHints].
export const hintCosts = {
  random: 3,
  initials: 4,
  fourth_instrument: 5,
} as const;

export type HintType = keyof typeof hintCosts;

export const hintTypes = new Set<string>(Object.keys(hintCosts));

/// Lo que puede salir en la pista sorpresa.
export const randomHints = ["first_letter", "last_letter", "artist"] as const;

/// Una pista sorpresa que el jugador aún no tiene, o null si ya las tiene
/// todas. [azar] devuelve un entero en [0, max).
export function pickRandomHint(
  usadas: readonly string[],
  azar: (max: number) => number,
): string | null {
  const quedan = randomHints.filter((tipo) => !usadas.includes(tipo));
  return quedan.length === 0 ? null : quedan[azar(quedan.length)];
}

/// Oculta las letras y números de un título manteniendo las iniciales visibles
/// y respetando espacios, acentos, números y puntuación (ej: "L__ c______ d_ l_ v___").
export function maskInitials(title: string): string {
  return title
    .split(" ")
    .map((word) => {
      let firstLetterSeen = false;
      let masked = "";
      for (const char of word) {
        if (/[\p{L}\p{N}]/u.test(char)) {
          if (!firstLetterSeen) {
            firstLetterSeen = true;
            masked += char;
          } else {
            masked += "_";
          }
        } else {
          masked += char;
        }
      }
      return masked;
    })
    .join(" ");
}

/// Primera o última letra (o número) del título, en mayúscula; "" si no hay.
export function titleLetter(title: string, last = false): string {
  const letters = [...title].filter((char) => /[\p{L}\p{N}]/u.test(char));
  const letter = last ? letters.at(-1) : letters[0];
  return letter?.toLocaleUpperCase() ?? "";
}

/// Pistas de intros: las primeras [introFreeHints] de cada cartera (género o
/// Medley) son gratis; después cada una cuesta [introHintPrice] moneda.
export const introFreeHints = 3;
export const introHintPrice = 1;

/// Inicial de cada palabra del título (se omiten las que no tienen letra ni número).
export function introInitials(title: string): string[] {
  return title.split(/\s+/).map((word) => titleLetter(word)).filter(Boolean);
}

/// Índice de una palabra aún no revelada, o null si ya salieron todas.
/// [azar] devuelve un entero en [0, max).
export function pickIntroHintWord(
  total: number,
  given: readonly number[],
  azar: (max: number) => number,
): number | null {
  const left = Array.from({ length: total }, (_, i) => i).filter((i) =>
    !given.includes(i)
  );
  return left.length === 0 ? null : left[azar(left.length)];
}
