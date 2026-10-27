// Configuración y utilidades del sistema de pistas (comodines) del juego.

export const hintCosts = {
  first_letter: 1,
  last_letter: 1,
  artist: 1,
  initials: 2,
  fourth_instrument: 3,
} as const;

export type HintType = keyof typeof hintCosts;

export const hintTypes = new Set<string>(Object.keys(hintCosts));

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
