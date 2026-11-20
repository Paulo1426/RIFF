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

/// Casillas del título para el jugador: una "_" por letra o número, palabras
/// separadas por espacio y puntuación visible. Se destapan según las pistas
/// compradas: "initials" (inicial de cada palabra), "first_letter" y
/// "last_letter" (primera y última del título, en mayúscula).
export function maskTitle(title: string, pistas: readonly string[]): string {
  const words = title.split(/\s+/).filter(Boolean);
  const isLetter = (char: string) => /[\p{L}\p{N}]/u.test(char);
  const total = [...title].filter(isLetter).length;
  const initials = pistas.includes("initials");
  let seen = 0;
  return words.map((word) => {
    let firstOfWord = true;
    let masked = "";
    for (const char of word) {
      if (!isLetter(char)) {
        masked += char;
        continue;
      }
      seen++;
      const show = (firstOfWord && initials) ||
        (seen === 1 && pistas.includes("first_letter")) ||
        (seen === total && pistas.includes("last_letter"));
      masked += show ? char.toLocaleUpperCase() : "_";
      firstOfWord = false;
    }
    return masked;
  }).join(" ");
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

/// Palabras del título sin la puntuación de los extremos.
export function introWords(title: string): string[] {
  return title.split(/\s+/)
    .map((word) => word.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, ""))
    .filter(Boolean);
}

/// Pistas que da como máximo: una por palabra si el título tiene 3 o más
/// palabras; si tiene 1 o 2, una por letra.
export function introHintTotal(title: string): number {
  const words = introWords(title);
  return words.length >= 3
    ? words.length
    : words.reduce((total, word) => total + [...word].length, 0);
}

/// Siguiente pista al azar o null si ya salieron todas; [given] son las dadas.
/// Cada pista es un texto "palabra:p" (palabra entera), "palabra:i" (su
/// inicial) o "palabra:l:letra" (una letra; la 0 es la inicial).
/// - 3 o más palabras: cada pista toca una palabra nueva y sale entera o solo
///   su inicial.
/// - 1 o 2 palabras: la primera pista es siempre la inicial de una palabra. La
///   segunda es la inicial de la otra palabra (si son 2) o una letra al azar
///   de cualquiera; de ahí en adelante, letras al azar.
/// [azar] devuelve un entero en [0, max).
export function pickIntroHint(
  title: string,
  given: readonly string[],
  azar: (max: number) => number,
): string | null {
  const words = introWords(title);
  if (words.length === 0) return null;
  if (words.length >= 3) {
    const used = new Set(given.map((hint) => Number(hint.split(":")[0])));
    const left = words.map((_, i) => i).filter((i) => !used.has(i));
    if (left.length === 0) return null;
    return `${left[azar(left.length)]}:${azar(2) === 0 ? "p" : "i"}`;
  }
  const shown = new Set(
    given.filter((hint) => hint.split(":").length === 3).map((hint) => {
      const [word, , letter] = hint.split(":");
      return `${word}:${letter}`;
    }),
  );
  const left = words.flatMap((word, w) => [...word].map((_, k) => ({ w, k })))
    .filter(({ w, k }) => !shown.has(`${w}:${k}`));
  if (left.length === 0) return null;
  const initials = left.filter(({ k }) => k === 0);
  const pick = shown.size === 0
    ? initials[azar(initials.length)]
    : initials.length > 0 && azar(2) === 0
    ? initials[0]
    : left[azar(left.length)];
  return `${pick.w}:l:${pick.k}`;
}

/// Lo que ve el jugador: con 3 o más palabras, una casilla por palabra (entera
/// o inicial); con 1 o 2, una casilla por letra y "/" entre palabras. "" es lo
/// que aún está oculto.
export function introHintView(
  title: string,
  given: readonly string[],
): string[] {
  const words = introWords(title);
  const upper = (text: string) => text.toLocaleUpperCase();
  if (words.length >= 3) {
    const byWord = new Map(
      given.map((hint) => hint.split(":") as [string, string]),
    );
    return words.map((word, i) => {
      const type = byWord.get(String(i));
      if (!type) return "";
      return type === "p" ? word : upper([...word][0]);
    });
  }
  const shown = new Set(
    given.filter((hint) => hint.split(":").length === 3).map((hint) => {
      const [word, , letter] = hint.split(":");
      return `${word}:${letter}`;
    }),
  );
  return words.flatMap((word, w) => [
    ...(w > 0 ? ["/"] : []),
    ...[...word].map((letter, k) =>
      shown.has(`${w}:${k}`) ? upper(letter) : ""
    ),
  ]);
}
