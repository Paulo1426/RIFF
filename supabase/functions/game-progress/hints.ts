// Configuración y utilidades del sistema de pistas (comodines) del juego.

export const hintCosts = {
  artist: 1,
  initials: 2,
  fourth_instrument: 3,
} as const;

export type HintType = keyof typeof hintCosts;

export const hintTypes = new Set<string>(["artist", "initials", "fourth_instrument"]);

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
